import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_drive_backup.dart';
import 'package:personal/features/location/data/timeline_export_writer.dart';
import 'package:personal/features/location/data/timeline_profile.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 20, 2);
  final summary = LocationSummary(
    activities: [
      TimelineActivity(
        startTime: t0.add(const Duration(hours: 9)),
        endTime: t0.add(const Duration(hours: 10)),
        type: 'IN_PASSENGER_VEHICLE',
        distanceMeters: 8200,
        probability: 0.8,
        source: TimelineSource.device,
      ),
    ],
    placeVisits: [
      TimelinePlaceVisit(
        startTime: t0,
        endTime: t0.add(const Duration(hours: 9)),
        name: 'Work',
        semanticType: 'TYPE_WORK',
        placeId: 'p-work',
        point: const GeoPoint(23.8679331, 90.4053536),
        probability: 0.9,
      ),
      TimelinePlaceVisit(
        startTime: t0.add(const Duration(hours: 10)),
        endTime: t0.add(const Duration(hours: 11)),
        name: 'Unknown place',
        placeId: 'p-cafe',
        point: const GeoPoint(23.79, 90.41),
        level: 1,
      ),
    ],
    profile: const LocationProfile(
      places: [
        ProfilePlace(
          placeId: 'p-work',
          point: GeoPoint(23.8679331, 90.4053536),
          label: 'WORK',
        ),
      ],
      trips: [
        FrequentTrip(
          direction: CommuteDirection.homeToWork,
          weekday: DateTime.tuesday,
          startMinutes: 485,
          durationMinutes: 40,
          modeShares: {'IN_PASSENGER_VEHICLE': 1},
        ),
      ],
      modeAffinities: {'WALKING': 0.4},
    ),
    trips: [
      TimelineTrip(
        startTime: t0,
        endTime: t0.add(const Duration(days: 3)),
        distanceFromOriginKm: 240,
        destinationPlaceIds: const ['p-dest'],
      ),
    ],
  );

  test('reads back with the export parser', () {
    final back = parseTimelineExport(
      encodeTimelineExport(summary, placeNames: const {'p-cafe': 'Cafe'}),
    );

    expect(back.activities, hasLength(1));
    final a = back.activities.single;
    expect(
      a.startTime.isAtSameMomentAs(summary.activities.single.startTime),
      isTrue,
    );
    expect(a.type, 'IN_PASSENGER_VEHICLE');
    expect(a.distanceMeters, 8200);

    expect(back.placeVisits, hasLength(2));
    final work = back.placeVisits.first;
    expect(work.isWork, isTrue);
    expect(work.placeId, 'p-work');
    expect(work.point!.latitude, closeTo(23.8679331, 1e-9));
    final cafe = back.placeVisits.last;
    expect(cafe.name, 'Cafe');
    expect(cafe.level, 1);

    expect(back.profile.work, isNotNull);
    final trip = back.profile.trips.single;
    expect(trip.weekday, DateTime.tuesday);
    expect(trip.startMinutes, 485);
    expect(trip.direction, CommuteDirection.homeToWork);
    expect(back.profile.modeAffinities['WALKING'], 0.4);

    expect(back.trips.single.distanceFromOriginKm, 240);
    expect(back.trips.single.destinationPlaceIds, ['p-dest']);
  });

  test('segments are in time order', () {
    final segments =
        timelineExportJson(summary)['semanticSegments'] as List<dynamic>;
    final starts = [
      for (final s in segments)
        DateTime.parse((s as Map)['startTime'] as String),
    ];
    for (var i = 1; i < starts.length; i++) {
      expect(starts[i].isBefore(starts[i - 1]), isFalse);
    }
  });

  test('timestamps carry the UTC offset', () {
    final stamp = timelineTimestamp(t0);
    expect(stamp, matches(RegExp(r'[+-]\d\d:\d\d$')));
    expect(DateTime.parse(stamp).isAtSameMomentAs(t0), isTrue);
  });

  test('content hash is stable', () {
    expect(fnv1a32('hello'.codeUnits), 0x4f9f2cab);
    expect(fnv1a32(const []), 0x811c9dc5);
  });
}
