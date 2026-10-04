import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/location/place_stats.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/timeline_profile.dart';

const _home = GeoPoint(23.8679, 90.4053);
const _work = GeoPoint(23.8593, 90.3651);
const _cafe = GeoPoint(23.7000, 90.3000);

TimelinePlaceVisit visit(
  String id,
  DateTime start,
  DateTime end, {
  String? type,
  GeoPoint? point,
  int level = 0,
}) => TimelinePlaceVisit(
  startTime: start,
  endTime: end,
  name: 'x',
  semanticType: type,
  placeId: id,
  point: point,
  level: level,
);

LocationSummary summaryOf(
  List<TimelinePlaceVisit> visits, {
  List<TimelineActivity> activities = const [],
}) => LocationSummary(
  activities: activities,
  placeVisits: visits,
  profile: const LocationProfile(
    places: [
      ProfilePlace(placeId: 'h', point: _home, label: 'HOME'),
      ProfilePlace(placeId: 'w', point: _work, label: 'WORK'),
    ],
  ),
);

void main() {
  final aug = DateTime(2026, 8, 1);
  final sep = DateTime(2026, 9, 1);
  final sepEnd = DateTime(2026, 9, 30, 23, 59);

  group('classifyPlaces', () {
    test('uses the majority of Google labels', () {
      final kinds = classifyPlaces(
        summaryOf([
          for (var i = 0; i < 5; i++)
            visit(
              'h1',
              DateTime(2026, 9, 1 + i),
              DateTime(2026, 9, 1 + i, 6),
              type: 'TYPE_HOME',
            ),
          visit('h1', DateTime(2026, 9, 9), DateTime(2026, 9, 9, 1)),
        ]),
      );
      expect(kinds['h1'], PlaceKind.home);
    });

    test('falls back to proximity to the profile home and work', () {
      final kinds = classifyPlaces(
        summaryOf([
          visit(
            'a',
            DateTime(2026, 9, 1),
            DateTime(2026, 9, 1, 2),
            point: _home,
          ),
          visit(
            'b',
            DateTime(2026, 9, 1, 3),
            DateTime(2026, 9, 1, 4),
            point: _work,
          ),
          visit(
            'c',
            DateTime(2026, 9, 1, 5),
            DateTime(2026, 9, 1, 6),
            point: _cafe,
          ),
        ]),
      );
      expect(kinds['a'], PlaceKind.home);
      expect(kinds['b'], PlaceKind.work);
      expect(kinds['c'], PlaceKind.other);
    });

    test('one stray label does not make a place home', () {
      final kinds = classifyPlaces(
        summaryOf([
          visit(
            'p',
            DateTime(2026, 9, 1),
            DateTime(2026, 9, 1, 1),
            type: 'TYPE_HOME',
            point: _cafe,
          ),
          for (var i = 0; i < 10; i++)
            visit(
              'p',
              DateTime(2026, 9, 2 + i),
              DateTime(2026, 9, 2 + i, 1),
              point: _cafe,
            ),
        ]),
      );
      expect(kinds['p'], PlaceKind.other);
    });
  });

  group('computeLocationInsights', () {
    test('counts a multi-day stay on every day it covers', () {
      final insights = computeLocationInsights(
        summaryOf([
          visit(
            'h',
            DateTime(2026, 9, 1, 18),
            DateTime(2026, 9, 4, 6),
            type: 'TYPE_HOME',
            point: _home,
          ),
        ]),
        sep,
        sepEnd,
      );
      expect(insights.split.days, 4);
      expect(insights.daily.first.home, const Duration(hours: 6));
      expect(insights.daily[1].home, const Duration(hours: 24));
      expect(insights.split.home, const Duration(hours: 60));
    });

    test('skips nested visits so time is not double counted', () {
      final insights = computeLocationInsights(
        summaryOf([
          visit(
            'mall',
            DateTime(2026, 9, 1, 10),
            DateTime(2026, 9, 1, 14),
            point: _cafe,
          ),
          visit(
            'shop',
            DateTime(2026, 9, 1, 11),
            DateTime(2026, 9, 1, 12),
            point: _cafe,
            level: 1,
          ),
        ]),
        sep,
        sepEnd,
      );
      expect(insights.split.elsewhere, const Duration(hours: 4));
      expect(insights.places.map((p) => p.placeId), ['mall']);
    });

    test('clips stays that begin before the period', () {
      final insights = computeLocationInsights(
        summaryOf([
          visit(
            'h',
            DateTime(2026, 8, 31, 20),
            DateTime(2026, 9, 1, 4),
            type: 'TYPE_HOME',
            point: _home,
          ),
        ]),
        DateTime(2026, 8, 31),
        sepEnd,
      );
      expect(insights.split.home, const Duration(hours: 8));
    });

    test('pairs home and work visits into commutes, first of the day only', () {
      final insights = computeLocationInsights(
        summaryOf([
          visit(
            'h',
            DateTime(2026, 9, 1, 0),
            DateTime(2026, 9, 1, 9, 40),
            type: 'TYPE_HOME',
            point: _home,
          ),
          visit(
            'w',
            DateTime(2026, 9, 1, 10),
            DateTime(2026, 9, 1, 17),
            type: 'TYPE_WORK',
            point: _work,
          ),
          visit(
            'h',
            DateTime(2026, 9, 1, 17, 40),
            DateTime(2026, 9, 1, 23),
            type: 'TYPE_HOME',
            point: _home,
          ),
        ]),
        sep,
        sepEnd,
      );
      final toWork = insights.commute.toWork.single;
      expect(toWork.duration, const Duration(minutes: 20));
      expect(
        CommuteStats.averageDepartureMinutes(insights.commute.toWork),
        9 * 60 + 40,
      );
      expect(
        insights.commute.toHome.single.duration,
        const Duration(minutes: 40),
      );
    });

    test('ignores a gap too long to be one commute', () {
      final insights = computeLocationInsights(
        summaryOf([
          visit(
            'h',
            DateTime(2026, 9, 1, 0),
            DateTime(2026, 9, 1, 6),
            type: 'TYPE_HOME',
            point: _home,
          ),
          visit(
            'w',
            DateTime(2026, 9, 1, 15),
            DateTime(2026, 9, 1, 17),
            type: 'TYPE_WORK',
            point: _work,
          ),
        ]),
        sep,
        sepEnd,
      );
      expect(insights.commute.toWork, isEmpty);
    });

    test('flags places first seen in the period, only when history exists', () {
      final withHistory = computeLocationInsights(
        summaryOf([
          visit(
            'old',
            DateTime(2026, 8, 1, 9),
            DateTime(2026, 8, 1, 11),
            point: _cafe,
          ),
          visit(
            'old',
            DateTime(2026, 9, 2, 9),
            DateTime(2026, 9, 2, 11),
            point: _cafe,
          ),
          visit(
            'new',
            DateTime(2026, 9, 3, 9),
            DateTime(2026, 9, 3, 11),
            point: _cafe,
          ),
        ]),
        sep,
        sepEnd,
      );
      expect(withHistory.uniquePlaces, 2);
      expect(withHistory.newPlaces, 1);

      final noHistory = computeLocationInsights(
        summaryOf([
          visit(
            'a',
            DateTime(2026, 9, 3, 9),
            DateTime(2026, 9, 3, 11),
            point: _cafe,
          ),
        ]),
        sep,
        sepEnd,
      );
      expect(noHistory.newPlaces, isNull);
    });

    test('does not count a passing stop as a place', () {
      final insights = computeLocationInsights(
        summaryOf([
          visit(
            'blip',
            DateTime(2026, 9, 3, 9),
            DateTime(2026, 9, 3, 9, 4),
            point: _cafe,
          ),
        ]),
        sep,
        sepEnd,
      );
      expect(insights.uniquePlaces, 0);
    });

    test('finds the furthest stop from home', () {
      final insights = computeLocationInsights(
        summaryOf([
          visit(
            'h',
            DateTime(2026, 9, 1),
            DateTime(2026, 9, 1, 8),
            type: 'TYPE_HOME',
            point: _home,
          ),
          visit(
            'far',
            DateTime(2026, 9, 2, 9),
            DateTime(2026, 9, 2, 12),
            point: _cafe,
          ),
        ]),
        sep,
        sepEnd,
      );
      expect(insights.furthestFromHomeKm, closeTo(21.5, 0.5));
      expect(insights.furthestOn, DateTime(2026, 9, 2, 9));
    });

    test('is empty when nothing falls in the period', () {
      final insights = computeLocationInsights(
        summaryOf([
          visit(
            'a',
            DateTime(2026, 7, 3, 9),
            DateTime(2026, 7, 3, 11),
            point: _cafe,
          ),
        ]),
        sep,
        sepEnd,
      );
      expect(insights.hasData, isFalse);
    });
  });

  group('buildMonthlyHistory', () {
    test('fills empty months so the axis is continuous', () {
      TimelineActivity ride(DateTime d, double km) => TimelineActivity(
        startTime: d,
        endTime: d.add(const Duration(minutes: 20)),
        type: 'MOTORCYCLING',
        distanceMeters: km * 1000,
      );
      final rows = buildMonthlyHistory(
        summaryOf(
          [
            visit(
              'w',
              DateTime(2026, 10, 2, 10),
              DateTime(2026, 10, 2, 17),
              type: 'TYPE_WORK',
              point: _work,
            ),
          ],
          activities: [
            ride(aug, 10),
            ride(aug.add(const Duration(days: 1)), 5),
            ride(DateTime(2026, 10, 3), 7),
          ],
        ),
      );
      expect(rows.map((r) => r.month.month), [8, 9, 10]);
      expect(rows[0].motorcycleKm, 15);
      expect(rows[0].rides, 2);
      expect(rows[1].totalKm, 0);
      expect(rows[2].workDays, 1);
    });

    test('is empty for an empty summary', () {
      expect(buildMonthlyHistory(summaryOf(const [])), isEmpty);
    });
  });
}
