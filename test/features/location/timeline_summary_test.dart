import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/location/timeline_activity.dart';

void main() {
  test('parseTimelineJsonActivities extracts activity segments', () {
    const raw = '''
{
  "semanticSegments": [
    {
      "startTime": "2026-05-10T08:00:00.000+06:00",
      "endTime": "2026-05-10T08:20:00.000+06:00",
      "activity": {
        "distanceMeters": 5000,
        "topCandidate": {
          "type": "MOTORCYCLING",
          "probability": 0.9
        }
      }
    },
    {
      "startTime": "2026-05-10T09:00:00.000+06:00",
      "endTime": "2026-05-10T09:40:00.000+06:00",
      "activity": {
        "distanceMeters": 1200,
        "topCandidate": {
          "type": "WALKING",
          "probability": 0.95
        }
      }
    }
  ]
}
''';

    final activities = parseTimelineJsonActivities(raw);
    expect(activities, hasLength(2));
    expect(activities.first.type, 'MOTORCYCLING');
    expect(activities.first.distanceMeters, 5000);
  });

  test('LocationSummary computes aggregate motorcycle prompt totals', () {
    final referenceDate = DateTime.parse('2026-05-27T10:00:00.000+06:00');
    final summary = LocationSummary(
      activities: [
        TimelineActivity(
          startTime: DateTime.parse('2026-04-30T20:00:00.000+06:00'),
          endTime: DateTime.parse('2026-04-30T20:20:00.000+06:00'),
          type: 'MOTORCYCLING',
          distanceMeters: 9000,
        ),
        TimelineActivity(
          startTime: DateTime.parse('2026-05-10T08:00:00.000+06:00'),
          endTime: DateTime.parse('2026-05-10T08:20:00.000+06:00'),
          type: 'MOTORCYCLING',
          distanceMeters: 5000,
        ),
        TimelineActivity(
          startTime: DateTime.parse('2026-05-11T10:00:00.000+06:00'),
          endTime: DateTime.parse('2026-05-11T10:30:00.000+06:00'),
          type: 'MOTORCYCLING',
          distanceMeters: 3500,
        ),
        TimelineActivity(
          startTime: DateTime.parse('2026-05-11T12:00:00.000+06:00'),
          endTime: DateTime.parse('2026-05-11T12:15:00.000+06:00'),
          type: 'WALKING',
          distanceMeters: 1000,
        ),
      ],
      fileName: 'Timeline.json',
    );

    final rides = summary.motorcyclingActivitiesInMonthToDate(
      referenceDate: referenceDate,
    );
    expect(rides, hasLength(2));
    expect(
      summary.motorcycleDistanceMetersInMonthToDate(
        referenceDate: referenceDate,
      ),
      8500,
    );
    expect(
      summary.monthToDateRangeLabel(referenceDate: referenceDate),
      '1 May 2026 – 27 May 2026',
    );

    final prompt = summary.toAnalysisPromptText(referenceDate: referenceDate);
    expect(prompt, contains('Motorcycle total distance: 8.50 km'));
    expect(prompt, isNot(contains('Motorcycle weekdays (Sun–Thu): ')));
    expect(prompt, isNot(contains('Motorcycle weekends (Fri–Sat): ')));
    expect(prompt, isNot(contains('Motorcycle segments:')));
  });

  test('LocationSummary splits motorcycle weekday/weekend totals', () {
    DateTime firstDayForWeekday(int targetWeekday) {
      final now = DateTime.now();
      var date = DateTime(now.year, now.month, 1, 8);
      while (date.weekday != targetWeekday) {
        date = date.add(const Duration(days: 1));
      }
      return date;
    }

    final sunday = firstDayForWeekday(DateTime.sunday);
    final friday = firstDayForWeekday(DateTime.friday);
    final wednesday = firstDayForWeekday(DateTime.wednesday);
    final thursday = firstDayForWeekday(DateTime.thursday);

    final summary = LocationSummary(
      activities: [
        TimelineActivity(
          startTime: sunday,
          endTime: sunday.add(const Duration(minutes: 30)),
          type: 'MOTORCYCLING',
          distanceMeters: 4000,
        ),
        TimelineActivity(
          startTime: friday.add(const Duration(hours: 1)),
          endTime: friday.add(const Duration(hours: 1, minutes: 20)),
          type: 'MOTORCYCLING',
          distanceMeters: 2500,
        ),
        TimelineActivity(
          startTime: wednesday.add(const Duration(hours: 2)),
          endTime: wednesday.add(const Duration(hours: 2, minutes: 40)),
          type: 'WALKING',
          distanceMeters: 1200,
        ),
        TimelineActivity(
          startTime: wednesday.add(const Duration(hours: 4)),
          endTime: wednesday.add(const Duration(hours: 4, minutes: 50)),
          type: 'DRIVING',
          distanceMeters: 5000,
        ),
        TimelineActivity(
          startTime: thursday.add(const Duration(hours: 4)),
          endTime: thursday.add(const Duration(hours: 4, minutes: 10)),
          type: 'WALKING',
          distanceMeters: 300,
        ),
      ],
    );

    expect(summary.motorcyclingWeekdayDistanceMeters, 4000);
    expect(summary.motorcyclingWeekendDistanceMeters, 2500);
  });
}
