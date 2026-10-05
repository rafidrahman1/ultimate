import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/location/mobility_prompt_builder.dart';
import 'package:personal/features/location/place_stats.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/timeline_profile.dart';

const _home = GeoPoint(23.8679331, 90.4053536);
const _work = GeoPoint(23.8593781, 90.3651591);
const _cafe = GeoPoint(23.7123456, 90.3123456);
const _gym = GeoPoint(23.7555555, 90.3777777);

TimelinePlaceVisit _visit(
  String id,
  DateTime start,
  DateTime end,
  GeoPoint point, {
  String? type,
}) => TimelinePlaceVisit(
  startTime: start,
  endTime: end,
  name: 'x',
  semanticType: type,
  placeId: id,
  point: point,
);

LocationSummary _build({Map<String, String> names = const {}}) {
  final visits = <TimelinePlaceVisit>[
    // History before the period, so "new places" can be worked out.
    _visit('gym-id', DateTime(2026, 8, 3, 18), DateTime(2026, 8, 3, 19), _gym),
    _visit(
      'home-id',
      DateTime(2026, 8, 3),
      DateTime(2026, 8, 3, 9),
      _home,
      type: 'TYPE_HOME',
    ),
    _visit(
      'work-id',
      DateTime(2026, 8, 3, 10),
      DateTime(2026, 8, 3, 17),
      _work,
      type: 'TYPE_WORK',
    ),
  ];
  for (var d = 1; d <= 10; d++) {
    visits
      ..add(
        _visit(
          'home-id',
          DateTime(2026, 9, d),
          DateTime(2026, 9, d, 9, 40),
          _home,
          type: 'TYPE_HOME',
        ),
      )
      ..add(
        _visit(
          'work-id',
          DateTime(2026, 9, d, 10),
          DateTime(2026, 9, d, 17),
          _work,
          type: 'TYPE_WORK',
        ),
      )
      ..add(
        _visit(
          'home-id',
          DateTime(2026, 9, d, 17, 40),
          DateTime(2026, 9, d, 23, 59),
          _home,
          type: 'TYPE_HOME',
        ),
      );
  }
  visits
    ..add(
      _visit(
        'cafe-id',
        DateTime(2026, 9, 5, 20),
        DateTime(2026, 9, 5, 22),
        _cafe,
      ),
    )
    ..add(
      _visit(
        'gym-id',
        DateTime(2026, 9, 6, 20),
        DateTime(2026, 9, 6, 21),
        _gym,
      ),
    );

  final base = LocationSummary(
    activities: [
      TimelineActivity(
        startTime: DateTime(2026, 9, 2, 10),
        endTime: DateTime(2026, 9, 2, 10, 20),
        type: 'MOTORCYCLING',
        distanceMeters: 8000,
      ),
    ],
    placeVisits: visits,
    profile: const LocationProfile(
      places: [
        ProfilePlace(placeId: 'home-id', point: _home, label: 'HOME'),
        ProfilePlace(placeId: 'work-id', point: _work, label: 'WORK'),
      ],
    ),
    trips: [
      TimelineTrip(
        startTime: DateTime(2026, 9, 12),
        endTime: DateTime(2026, 9, 15),
        distanceFromOriginKm: 239,
      ),
    ],
  );
  return LocationSummary(
    activities: base.activities,
    placeVisits: base.placeVisits,
    profile: base.profile,
    trips: base.trips,
    insights: computeLocationInsights(
      base,
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 30, 23, 59),
    ),
    placeNames: names,
  );
}

String _prompt(LocationSummary s, {LocationInsights? previous}) =>
    buildMobilityPromptText(
      summary: s,
      previousInsights: previous,
      dataMonthStart: DateTime(2026, 9, 1),
      dataMonthEnd: DateTime(2026, 9, 30, 23, 59),
    );

void main() {
  test('summarises time, places, commute and trips away', () {
    final text = _prompt(_build());
    expect(text, contains('Places & Time:'));
    expect(text, contains('Time per tracked day: home'));
    expect(text, contains('Time away from home:'));
    expect(text, contains('Places visited:'));
    expect(text, contains('Home: 20 visits'));
    expect(text, contains('Work: 10 visits'));
    expect(text, contains('Commute (door to door'));
    expect(
      text,
      contains('To work: average 20m over 10 days, usually leaves 09:40'),
    );
    expect(text, contains('Trips away from home:'));
    expect(text, contains('up to 239 km from home (3 days)'));
  });

  test('counts unnamed places instead of listing them', () {
    final text = _prompt(_build());
    expect(text, contains('Other (unnamed) places: 2'));
    expect(text, isNot(contains('Unnamed place')));
  });

  test('lists a place once the user has named it', () {
    final text = _prompt(_build(names: {'cafe-id': 'Corner cafe'}));
    expect(text, contains('Corner cafe: 1 visits'));
    expect(text, contains('Other (unnamed) places: 1'));
  });

  test('reports places not seen in earlier months', () {
    final text = _prompt(_build());
    // The gym was visited in August, the cafe is new.
    expect(text, contains('(1 not seen in earlier months)'));
  });

  test('never includes coordinates or place ids', () {
    final text = _prompt(_build(names: {'cafe-id': 'Corner cafe'}));
    for (final leak in [
      'home-id',
      'work-id',
      'cafe-id',
      'gym-id',
      '°',
      '23.8',
      '90.4',
      '23.71',
    ]) {
      expect(text, isNot(contains(leak)), reason: 'leaked "$leak"');
    }
  });

  test('compares time away with the previous period', () {
    final previous = computeLocationInsights(
      _build(),
      DateTime(2026, 8, 1),
      DateTime(2026, 8, 31, 23, 59),
    );
    final text = _prompt(_build(), previous: previous);
    expect(text, contains('previous period'));
  });

  test('omits the section when the period has no visits', () {
    final empty = LocationSummary(
      activities: [
        TimelineActivity(
          startTime: DateTime(2026, 9, 2, 10),
          endTime: DateTime(2026, 9, 2, 10, 20),
          type: 'MOTORCYCLING',
          distanceMeters: 8000,
        ),
      ],
      insights: LocationInsights.empty,
    );
    final text = _prompt(empty);
    expect(text, isNot(contains('Places & Time')));
    expect(text, contains('Travel:'));
  });
}
