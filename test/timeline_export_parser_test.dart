import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/location/data/timeline_activity.dart';

void main() {
  test('keeps complete activities and skips unusable ones', () {
    final raw = jsonEncode({
      'semanticSegments': [
        {
          'startTime': '2026-11-01T08:00:00.000+06:00',
          'endTime': '2026-11-01T08:30:00.000+06:00',
          'activity': {
            'distanceMeters': 5200.5,
            'topCandidate': {
              'type': 'IN_PASSENGER_VEHICLE',
              'probability': 0.9,
            },
          },
        },
        // No distance.
        {
          'startTime': '2026-11-01T09:00:00.000+06:00',
          'endTime': '2026-11-01T09:30:00.000+06:00',
          'activity': {
            'topCandidate': {'type': 'WALKING'},
          },
        },
        // No end time.
        {
          'startTime': '2026-11-01T10:00:00.000+06:00',
          'activity': {
            'distanceMeters': 10,
            'topCandidate': {'type': 'WALKING'},
          },
        },
        'not a segment',
      ],
    });
    final activities = parseTimelineJsonActivities(raw);
    expect(activities, hasLength(1));
    expect(activities.single.type, 'IN_PASSENGER_VEHICLE');
    expect(activities.single.distanceMeters, 5200.5);
    expect(activities.single.probability, 0.9);
    expect(
      activities.single.endTime.difference(activities.single.startTime),
      const Duration(minutes: 30),
    );
  });

  test('an export without segments is empty, a non-object root throws', () {
    expect(parseTimelineJsonActivities('{}'), isEmpty);
    expect(parseTimelineJsonPlaceVisits('{"semanticSegments": 3}'), isEmpty);
    expect(() => parseTimelineJsonActivities('[]'), throwsFormatException);
  });
}
