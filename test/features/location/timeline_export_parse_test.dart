import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/timeline_profile.dart';

/// Mirrors the on-device Google Maps Timeline export: visits carry a place id
/// and coordinates but no name, coordinates are `"lat°, lng°"` strings, and
/// routine start times are minutes since Monday 00:00.
Map<String, dynamic> _fixture() => {
  'semanticSegments': [
    {
      'startTime': '2026-09-01T08:00:00.000+06:00',
      'endTime': '2026-09-01T10:00:00.000+06:00',
      'visit': {
        'hierarchyLevel': 0,
        'probability': 0.9,
        'topCandidate': {
          'placeId': 'home-id',
          'semanticType': 'HOME',
          'probability': 0.95,
          'placeLocation': {'latLng': '23.8679331°, 90.4053536°'},
        },
      },
    },
    {
      'startTime': '2026-09-01T10:00:00.000+06:00',
      'endTime': '2026-09-01T10:30:00.000+06:00',
      'activity': {
        'start': {'latLng': '23.8679331°, 90.4053536°'},
        'end': {'latLng': '23.8593781°, 90.3651591°'},
        'distanceMeters': 8200.5,
        'probability': 0.8,
        'topCandidate': {'type': 'MOTORCYCLING', 'probability': 0.8},
      },
    },
    {
      'startTime': '2026-09-01T10:30:00.000+06:00',
      'endTime': '2026-09-01T18:00:00.000+06:00',
      'visit': {
        'hierarchyLevel': 0,
        'topCandidate': {
          'placeId': 'cafe-id',
          'semanticType': 'UNKNOWN',
          'placeLocation': {'latLng': '23.7°, 90.3°'},
        },
      },
    },
    {
      'startTime': '2026-09-01T12:00:00.000+06:00',
      'endTime': '2026-09-01T12:20:00.000+06:00',
      'visit': {
        'hierarchyLevel': 1,
        'topCandidate': {
          'placeId': 'shop-id',
          'semanticType': 'UNKNOWN',
          'placeLocation': {'latLng': '23.7°, 90.3°'},
        },
      },
    },
    {
      'startTime': '2026-09-01T10:00:00.000+06:00',
      'endTime': '2026-09-01T10:30:00.000+06:00',
      'timelinePath': [
        {'point': '23.86°, 90.40°', 'time': '2026-09-01T10:05:00.000+06:00'},
      ],
    },
    {
      'startTime': '2026-08-10T00:00:00.000+06:00',
      'endTime': '2026-08-15T00:00:00.000+06:00',
      'timelineMemory': {
        'trip': {
          'distanceFromOriginKms': 239,
          'destinations': [
            {
              'identifier': {'placeId': 'far-id'},
            },
          ],
        },
      },
    },
  ],
  'rawSignals': [
    {
      'wifiScan': {'deliveryTime': '2026-09-01T10:00:00.000+06:00'},
    },
  ],
  'userLocationProfile': {
    'frequentPlaces': [
      {
        'placeId': 'home-id',
        'placeLocation': '23.8679331°, 90.4053536°',
        'label': 'HOME',
      },
      {
        'placeId': 'work-id',
        'placeLocation': '23.8593781°, 90.3651591°',
        'label': 'WORK',
      },
      {'placeId': 'other-id', 'placeLocation': '23.80°, 90.30°'},
    ],
    'frequentTrips': [
      {
        'waypointIds': ['home-id', 'work-id'],
        'modeDistribution': [
          {'mode': 'MOTORCYCLING', 'rate': 0.72},
          {'mode': 'UNKNOWN_ACTIVITY_TYPE', 'rate': 0.09},
        ],
        // Sunday (day 6) 10:06
        'startTimeMinutes': 6 * 1440 + 10 * 60 + 6,
        'endTimeMinutes': 6 * 1440 + 10 * 60 + 27,
        'durationMinutes': 21,
        'confidence': 0.97,
        'commuteDirection': 'COMMUTE_DIRECTION_HOME_TO_WORK',
      },
    ],
    'persona': {
      'travelModeAffinities': [
        {'mode': 'MOTORCYCLING', 'affinity': 0.72},
      ],
    },
  },
};

void main() {
  group('parseGeoPoint', () {
    test('reads the export format with degree signs', () {
      final p = parseGeoPoint('23.8679331°, 90.4053536°')!;
      expect(p.latitude, closeTo(23.8679331, 1e-9));
      expect(p.longitude, closeTo(90.4053536, 1e-9));
    });

    test('rejects garbage and out-of-range values', () {
      expect(parseGeoPoint('nowhere'), isNull);
      expect(parseGeoPoint('95.0°, 10.0°'), isNull);
      expect(parseGeoPoint(null), isNull);
    });

    test('computes distances', () {
      const a = GeoPoint(23.8679331, 90.4053536);
      const b = GeoPoint(23.8593781, 90.3651591);
      expect(a.distanceTo(b) / 1000, closeTo(4.2, 0.3));
      expect(a.distanceTo(a), 0);
    });
  });

  group('parseTimelineExport', () {
    final summary = parseTimelineExport(jsonEncode(_fixture()), fileName: 'x');

    test('keeps visits that Google could not classify', () {
      final unknown = summary.placeVisits.where((v) => v.placeId == 'cafe-id');
      expect(unknown, hasLength(1));
      expect(unknown.single.semanticType, isNull);
      expect(unknown.single.point, isNotNull);
    });

    test('marks nested visits so dwell sums can skip them', () {
      expect(summary.placeVisits.where((v) => v.isNested), hasLength(1));
      expect(
        summary.placeVisits.firstWhere((v) => v.placeId == 'shop-id').level,
        1,
      );
    });

    test('reads home from a typed visit', () {
      final home = summary.placeVisits.firstWhere((v) => v.isAtHome);
      expect(home.placeId, 'home-id');
      expect(home.probability, 0.9);
    });

    test('reads activities and ignores path and raw signal segments', () {
      expect(summary.activities, hasLength(1));
      expect(summary.activities.single.isMotorcycling, isTrue);
    });

    test('unpacks routines: weekday and time of day', () {
      final trip = summary.profile.trips.single;
      expect(trip.direction, CommuteDirection.homeToWork);
      expect(trip.weekday, DateTime.sunday);
      expect(trip.startMinutes, 10 * 60 + 6);
      expect(trip.dominantMode, 'MOTORCYCLING');
      expect(trip.durationMinutes, 21);
    });

    test('reads labelled places and mode affinities', () {
      expect(summary.profile.home, isNotNull);
      expect(summary.profile.work, isNotNull);
      expect(summary.profile.places, hasLength(3));
      expect(summary.profile.modeAffinities['MOTORCYCLING'], 0.72);
    });

    test('reads multi-day trips', () {
      final trip = summary.trips.single;
      expect(trip.distanceFromOriginKm, 239);
      expect(trip.duration.inDays, 5);
      expect(trip.destinationPlaceIds, ['far-id']);
    });

    test('rejects a file that is not a timeline object', () {
      expect(() => parseTimelineExport('[]'), throwsFormatException);
    });
  });

  test('background parse matches the synchronous parse', () async {
    final raw = jsonEncode(_fixture());
    final viaIsolate = await parseTimelineExportInBackground(
      Uint8List.fromList(utf8.encode(raw)),
      fileName: 'x',
    );
    expect(viaIsolate.placeVisits, hasLength(3));
    expect(viaIsolate.profile.trips, hasLength(1));
  });
}
