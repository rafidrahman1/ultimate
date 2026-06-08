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
    expect(summary.periodMotorcycleTravelTime, const Duration(hours: 1, minutes: 10));
    final mayActivities = summary.activitiesInRange(
      DateTime(2026, 5, 1),
      DateTime(2026, 5, 27, 23, 59, 59, 999, 999),
    );
    expect(
      LocationSummary(activities: mayActivities).periodMotorcycleTravelTime,
      const Duration(minutes: 50),
    );
    expect(
      summary.monthToDateRangeLabel(referenceDate: referenceDate),
      '1 May 2026 – 27 May 2026',
    );

    final prompt = summary.toAnalysisPromptText(referenceDate: referenceDate);
    expect(prompt, contains('Motorcycle total distance: 8.50 km'));
    expect(prompt, contains('Motorcycle total travel time: 50m'));
    expect(prompt, isNot(contains('Motorcycle weekdays (Sun–Thu): ')));
    expect(prompt, isNot(contains('Motorcycle weekends (Fri–Sat): ')));
    expect(prompt, isNot(contains('Motorcycle segments:')));
  });
}
