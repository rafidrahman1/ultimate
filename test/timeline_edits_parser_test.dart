import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/location/timeline_edits_parser.dart';
import 'package:personal/features/location/timeline_entry.dart';

void main() {
  test('parses visit and activity from Timeline Edits.json shape', () {
    const json = '''
{
  "timelineEdits": [{
    "deviceId": "1",
    "inferredSemanticSegment": {
      "startTime": "2026-05-12T06:35:48.740Z",
      "endTime": "2026-05-12T12:00:02.040Z",
      "segment": {
        "visit": {
          "topCandidate": {
            "placeId": "ChIJtest",
            "semanticType": "WORK",
            "placeLocation": { "latE7": 237948384, "lngE7": 904034143 }
          }
        }
      }
    }
  }, {
    "deviceId": "1",
    "inferredSemanticSegment": {
      "startTime": "2026-05-12T06:31:46.343Z",
      "endTime": "2026-05-12T06:35:48.740Z",
      "segment": {
        "activity": {
          "start": { "latE7": 237910872, "lngE7": 904037218 },
          "end": { "latE7": 237932172, "lngE7": 904029356 },
          "distanceMeters": 250.0,
          "topCandidate": { "type": "WALKING", "probability": 0.83 }
        }
      }
    }
  }]
}
''';

    final entries = parseTimelineEditsJson(json);

    expect(entries, hasLength(2));
    expect(entries[0].kind, TimelineEntryKind.visit);
    expect(entries[0].title, 'Work');
    expect(entries[0].placeId, 'ChIJtest');
    expect(entries[1].kind, TimelineEntryKind.activity);
    expect(entries[1].title, 'Walking');
    expect(entries[1].activityType, 'WALKING');
    expect(entries[1].distanceMeters, 250.0);
  });

  test('aggregates distance by travel mode for AI summary', () {
    final summary = LocationHistorySummary(
      forMonth: DateTime(2026, 5, 15),
      entries: [
        TimelineEntry(
          kind: TimelineEntryKind.activity,
          startTime: DateTime(2026, 4, 30),
          endTime: DateTime(2026, 4, 30, 1),
          title: 'Walking',
          subtitle: '',
          latitude: 0,
          longitude: 0,
          activityType: 'WALKING',
          distanceMeters: 9999,
        ),
        TimelineEntry(
          kind: TimelineEntryKind.activity,
          startTime: DateTime(2026, 5, 1),
          endTime: DateTime(2026, 5, 1, 1),
          title: 'Motorcycling',
          subtitle: '',
          latitude: 0,
          longitude: 0,
          activityType: 'MOTORCYCLING',
          distanceMeters: 5000,
        ),
        TimelineEntry(
          kind: TimelineEntryKind.activity,
          startTime: DateTime(2026, 5, 2),
          endTime: DateTime(2026, 5, 2, 1),
          title: 'Motorcycling',
          subtitle: '',
          latitude: 0,
          longitude: 0,
          activityType: 'MOTORCYCLING',
          distanceMeters: 3000,
        ),
        TimelineEntry(
          kind: TimelineEntryKind.activity,
          startTime: DateTime(2026, 5, 3),
          endTime: DateTime(2026, 5, 3, 1),
          title: 'Walking',
          subtitle: '',
          latitude: 0,
          longitude: 0,
          activityType: 'WALKING',
          distanceMeters: 500,
        ),
      ],
    );

    expect(summary.monthEntries, hasLength(3));

    final modes = summary.travelByMode;
    expect(modes, hasLength(2));
    expect(modes.first.mode, 'MOTORCYCLING');
    expect(modes.first.distanceKm, 8.0);
    expect(modes.first.tripCount, 2);

    expect(summary.periodRangeLabel, isNotNull);
    expect(summary.periodDays, 3);

    final ai = summary.toAiSummary();
    expect(ai, contains('May 2026'));
    expect(ai, contains('Dates in month:'));
    expect(ai, contains('Motorcycling: 8.0 km (2 trips)'));
    expect(ai, contains('Walking: 0.5 km (1 trips)'));
  });

  test('toAnalysisPromptText uses compact summary for motorcycle only', () {
    final summary = LocationHistorySummary(
      forMonth: DateTime(2026, 5, 15),
      entries: [
        TimelineEntry(
          kind: TimelineEntryKind.activity,
          startTime: DateTime(2026, 5, 1),
          endTime: DateTime(2026, 5, 1, 1),
          title: 'Motorcycling',
          subtitle: '',
          latitude: 0,
          longitude: 0,
          activityType: 'MOTORCYCLING',
          distanceMeters: 5000,
        ),
        TimelineEntry(
          kind: TimelineEntryKind.activity,
          startTime: DateTime(2026, 5, 2),
          endTime: DateTime(2026, 5, 2, 1),
          title: 'Walking',
          subtitle: '',
          latitude: 0,
          longitude: 0,
          activityType: 'WALKING',
          distanceMeters: 500,
        ),
        TimelineEntry(
          kind: TimelineEntryKind.visit,
          startTime: DateTime(2026, 5, 3),
          endTime: DateTime(2026, 5, 3, 4),
          title: 'Work',
          subtitle: 'WORK',
          latitude: 0,
          longitude: 0,
          visitType: 'WORK',
        ),
      ],
    );

    final prompt = summary.toAnalysisPromptText();
    expect(prompt, contains('Month: May 2026'));
    expect(prompt, contains('Distance: 5.0 km'));
    expect(prompt, contains('Trips: 1, Visits: 1'));
    expect(prompt, contains('Top travel mode: Motorcycling'));
    expect(prompt, isNot(contains('Walking')));
    expect(prompt, isNot(contains('8.0 km')));
  });
}
