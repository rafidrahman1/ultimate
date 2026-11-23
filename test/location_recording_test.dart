import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/location/data/location_edits.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_merge.dart';
import 'package:personal/features/location/data/timeline_profile.dart';
import 'package:personal/features/location/recording/raw_location_log.dart';
import 'package:personal/features/location/recording/recorded_timeline_builder.dart';
import 'package:personal/features/location/recording/timeline_segmenter.dart';
import 'package:personal/features/location/recording/travel_mode_classifier.dart';

const home = GeoPoint(23.8679331, 90.4053536);
const work = GeoPoint(23.7948384, 90.4034143);

final day = DateTime(2026, 11, 20);
int at(int hour, [int minute = 0]) =>
    day.add(Duration(hours: hour, minutes: minute)).millisecondsSinceEpoch;

/// Fixes every [stepSec] seconds at [p] with a little jitter.
List<RawFix> stay(GeoPoint p, int fromMs, int toMs, {int stepSec = 120}) => [
  for (var t = fromMs, i = 0; t <= toMs; t += stepSec * 1000, i++)
    RawFix(
      timeMs: t,
      lat: p.latitude + (i % 3 - 1) * 0.0001,
      lng: p.longitude + (i % 2) * 0.0001,
      accuracy: 20,
    ),
];

/// A straight ride from [a] to [b], a fix every 10 s.
List<RawFix> ride(GeoPoint a, GeoPoint b, int fromMs, int toMs) {
  final steps = (toMs - fromMs) ~/ 10000;
  return [
    for (var i = 1; i < steps; i++)
      RawFix(
        timeMs: fromMs + i * 10000,
        lat: a.latitude + (b.latitude - a.latitude) * i / steps,
        lng: a.longitude + (b.longitude - a.longitude) * i / steps,
        accuracy: 8,
      ),
  ];
}

void main() {
  group('raw log', () {
    test('parses fixes and activities and skips broken lines', () {
      final log = parseRawLogLines([
        '{"k":"p","t":2000,"la":23.86,"lo":90.40,"ac":12.0,"sp":3.4}',
        '{"k":"a","t":1000,"a":"IN_VEHICLE","e":1}',
        '{"k":"p","t":3000,"la":23.8', // cut off by a crash
        '{"k":"s","t":500,"e":"start"}',
        '{"k":"p","t":100,"la":1,"lo":2}',
      ], fromMs: 1000);
      expect(log.fixes, hasLength(1));
      expect(log.fixes.single.speed, 3.4);
      expect(log.activities.single.activity, 'IN_VEHICLE');
      expect(log.activities.single.enter, isTrue);
    });
  });

  group('segmenter', () {
    test('home, ride, work becomes visit, trip, visit', () {
      final log = RawLog(
        fixes: [
          ...stay(home, at(0), at(8)),
          ...ride(home, work, at(8), at(8, 30)),
          ...stay(work, at(8, 30), at(17)),
        ],
        activities: [
          RawActivityEvent(
            timeMs: at(8, 1),
            activity: 'IN_VEHICLE',
            enter: true,
          ),
          RawActivityEvent(
            timeMs: at(8, 31),
            activity: 'IN_VEHICLE',
            enter: false,
          ),
          RawActivityEvent(timeMs: at(8, 31), activity: 'STILL', enter: true),
        ],
      );
      final segments = segmentTimeline(log);
      expect(segments.map((s) => s.kind), [
        RecordedKind.visit,
        RecordedKind.move,
        RecordedKind.visit,
      ]);
      final trip = segments[1];
      expect(trip.activity, 'IN_VEHICLE');
      expect(trip.distanceMeters, closeTo(home.distanceTo(work), 400));
      expect(trip.start.hour, 8);
      expect(segments.first.center!.distanceTo(home), lessThan(50));
      expect(segments.last.center!.distanceTo(work), lessThan(50));
    });

    test('a jam in a vehicle is not a visit', () {
      const mid = GeoPoint(23.83, 90.404);
      final log = RawLog(
        fixes: [
          ...stay(home, at(0), at(8)),
          ...ride(home, mid, at(8), at(8, 15)),
          ...stay(mid, at(8, 15), at(8, 23), stepSec: 30),
          ...ride(mid, work, at(8, 23), at(8, 40)),
          ...stay(work, at(8, 40), at(17)),
        ],
        activities: [
          RawActivityEvent(
            timeMs: at(8, 1),
            activity: 'IN_VEHICLE',
            enter: true,
          ),
          RawActivityEvent(timeMs: at(8, 41), activity: 'STILL', enter: true),
        ],
      );
      final visits = segmentTimeline(log).where((s) => s.isVisit).toList();
      expect(visits, hasLength(2));
    });

    test('splits a trip where the activity changes', () {
      const stop = GeoPoint(23.86, 90.405);
      final log = RawLog(
        fixes: [
          ...stay(home, at(0), at(8)),
          ...ride(home, stop, at(8), at(8, 10)),
          ...ride(stop, work, at(8, 10), at(8, 50)),
          ...stay(work, at(8, 50), at(17)),
        ],
        activities: [
          RawActivityEvent(timeMs: at(8), activity: 'WALKING', enter: true),
          RawActivityEvent(
            timeMs: at(8, 10),
            activity: 'IN_VEHICLE',
            enter: true,
          ),
          RawActivityEvent(timeMs: at(8, 50), activity: 'STILL', enter: true),
        ],
      );
      final moves = segmentTimeline(log).where((s) => !s.isVisit).toList();
      expect(moves.map((m) => m.activity), ['WALKING', 'IN_VEHICLE']);
    });

    test('segments survive a json round trip', () {
      const segment = RecordedSegment(
        kind: RecordedKind.move,
        startMs: 1000,
        endMs: 2000,
        distanceMeters: 1234,
        p90Kmh: 31.5,
        activity: 'IN_VEHICLE',
        from: home,
        to: work,
      );
      final back = RecordedSegment.fromJson(segment.toJson())!;
      expect(back.kind, RecordedKind.move);
      expect(back.distanceMeters, 1234);
      expect(back.activity, 'IN_VEHICLE');
      expect(back.to!.latitude, work.latitude);
    });
  });

  group('travel mode classifier', () {
    List<LabelledTrip> history() => [
      for (var i = 0; i < 50; i++)
        LabelledTrip(type: TravelModes.motorcycling, avgKmh: 18 + (i % 5)),
      for (var i = 0; i < 10; i++)
        LabelledTrip(type: TravelModes.car, avgKmh: 28 + (i % 4)),
      for (var i = 0; i < 20; i++)
        LabelledTrip(type: TravelModes.walking, avgKmh: 4 + (i % 3) * 0.5),
    ];

    test('picks your usual vehicle at your usual speed', () {
      final model = TravelModeClassifier.train(history());
      expect(
        model.classify(avgKmh: 20, activity: 'IN_VEHICLE'),
        TravelModes.motorcycling,
      );
      // Android often senses a motorbike as a bicycle.
      expect(
        model.classify(avgKmh: 20, activity: 'ON_BICYCLE'),
        TravelModes.motorcycling,
      );
      expect(
        model.classify(avgKmh: 4.5, activity: 'WALKING'),
        TravelModes.walking,
      );
      expect(model.classify(avgKmh: 4.5), TravelModes.walking);
    });

    test('learns from corrections', () {
      final before = TravelModeClassifier.train(history());
      expect(
        before.classify(avgKmh: 11, activity: 'IN_VEHICLE'),
        isNot(TravelModes.bus),
      );
      final after = TravelModeClassifier.train([
        ...history(),
        for (var i = 0; i < 8; i++)
          LabelledTrip(type: TravelModes.bus, avgKmh: 10 + (i % 3), weight: 3),
      ]);
      expect(
        after.classify(avgKmh: 11, activity: 'IN_VEHICLE'),
        TravelModes.bus,
      );
    });
  });

  group('recorded timeline builder', () {
    RecordedSegment visitAt(GeoPoint p, int from, int to) => RecordedSegment(
      kind: RecordedKind.visit,
      startMs: from,
      endMs: to,
      center: p,
    );

    test('reuses known places and makes stable ids for new ones', () {
      const gym = GeoPoint(23.80, 90.41);
      const nearGym = GeoPoint(23.8003, 90.4101);
      final summary = buildRecordedSummary(
        segments: [
          visitAt(const GeoPoint(23.8681, 90.4054), at(0), at(8)),
          visitAt(gym, at(18), at(19)),
          visitAt(nearGym, at(20), at(21)),
        ],
        knownPlaces: const [
          KnownPlace(id: 'google-home', point: home, semanticType: 'TYPE_HOME'),
        ],
        classifier: TravelModeClassifier.train(const []),
      );
      final visits = summary.placeVisits;
      expect(visits[0].placeId, 'google-home');
      expect(visits[0].isAtHome, isTrue);
      expect(visits[0].source, TimelineSource.device);
      expect(visits[1].placeId, startsWith('dev:'));
      expect(visits[2].placeId, visits[1].placeId);
    });

    test('infers home from nights when there is no history', () {
      final segments = [
        for (var d = 0; d < 4; d++)
          visitAt(
            home,
            DateTime(2026, 11, 10 + d, 0).millisecondsSinceEpoch,
            DateTime(2026, 11, 10 + d, 8).millisecondsSinceEpoch,
          ),
      ];
      final summary = buildRecordedSummary(
        segments: segments,
        knownPlaces: const [],
        classifier: TravelModeClassifier.train(const []),
      );
      expect(summary.placeVisits.every((v) => v.isAtHome), isTrue);
      expect(summary.profile.home, isNotNull);
    });
  });

  group('corrections', () {
    DateTime t(int hour, [int minute = 0]) =>
        day.add(Duration(hours: hour, minutes: minute));

    LocationSummary sample({Duration stretch = Duration.zero}) =>
        LocationSummary(
          activities: [
            TimelineActivity(
              startTime: t(8, 30),
              endTime: t(9),
              type: TravelModes.car,
              distanceMeters: 3000,
            ),
            TimelineActivity(
              startTime: t(10),
              endTime: t(10, 30).add(stretch),
              type: TravelModes.motorcycling,
              distanceMeters: 4000,
            ),
          ],
          placeVisits: [
            TimelinePlaceVisit(
              startTime: t(9),
              endTime: t(10),
              name: 'Unnamed place',
              placeId: 'shop',
              point: const GeoPoint(23.85, 90.40),
            ),
          ],
        );

    test('changes a trip mode, and keeps applying when it is re-detected', () {
      final edits = LocationEdits(
        edits: [
          LocationEdit(
            id: 'e1',
            kind: LocationEditKind.mode,
            isVisit: false,
            matchStart: t(10),
            matchEnd: t(10, 30),
            type: TravelModes.bus,
          ),
        ],
      );
      for (final stretch in [Duration.zero, const Duration(minutes: 5)]) {
        final result = applyLocationEdits(sample(stretch: stretch), edits);
        final trip = result.activities.last;
        expect(trip.type, TravelModes.bus);
        expect(trip.editIds, ['e1']);
        expect(result.activities.first.type, TravelModes.car);
      }
    });

    test('removing a stop joins the trips around it', () {
      final result = applyLocationEdits(
        sample(),
        LocationEdits(
          edits: [
            LocationEdit(
              id: 'r1',
              kind: LocationEditKind.remove,
              isVisit: true,
              matchStart: t(9),
              matchEnd: t(10),
            ),
          ],
        ),
      );
      expect(result.placeVisits, isEmpty);
      final trip = result.activities.single;
      expect(trip.startTime, t(8, 30));
      expect(trip.endTime, t(10, 30));
      expect(trip.distanceMeters, 7000);
      expect(trip.type, TravelModes.motorcycling);
      expect(trip.editIds, contains('r1'));
    });

    test('times and place changes, and home marks', () {
      final result = applyLocationEdits(
        sample(),
        LocationEdits(
          edits: [
            LocationEdit(
              id: 'e1',
              kind: LocationEditKind.times,
              isVisit: true,
              matchStart: t(9),
              matchEnd: t(10),
              newStart: t(9, 10),
              newEnd: t(9, 50),
            ),
            LocationEdit(
              id: 'e2',
              kind: LocationEditKind.place,
              isVisit: true,
              matchStart: t(9),
              matchEnd: t(10),
              placeId: 'usr:mum',
              placeName: 'Mum',
              point: const GeoPoint(23.851, 90.401),
            ),
          ],
          placeKinds: const {'usr:mum': PlaceKindOverride.home},
        ),
      );
      final visit = result.placeVisits.single;
      expect(visit.startTime, t(9, 10));
      expect(visit.endTime, t(9, 50));
      expect(visit.sourceStart, t(9));
      expect(visit.placeId, 'usr:mum');
      expect(visit.isAtHome, isTrue);
      expect(visit.editIds, ['e1', 'e2']);
      expect(result.profile.home!.latitude, 23.851);
    });

    test('edits survive a json round trip', () {
      final edits = LocationEdits(
        edits: [
          LocationEdit(
            id: 'e1',
            kind: LocationEditKind.place,
            isVisit: true,
            matchStart: t(9),
            matchEnd: t(10),
            placeId: 'x',
            point: home,
          ),
        ],
        placeKinds: const {'x': PlaceKindOverride.work},
      );
      final back = LocationEdits.fromJson(edits.toJson());
      expect(back.edits.single.placeId, 'x');
      expect(back.edits.single.point!.latitude, home.latitude);
      expect(back.edits.single.matches(t(9), t(10), visit: true), isTrue);
      expect(back.placeKinds['x'], PlaceKindOverride.work);
    });
  });

  group('merge', () {
    DateTime t(int hour) => day.add(Duration(hours: hour));

    test('google up to the end of the export, recorded after', () {
      final imported = LocationSummary(
        activities: [
          TimelineActivity(
            startTime: t(10),
            endTime: t(12),
            type: TravelModes.car,
            distanceMeters: 1000,
          ),
        ],
      );
      final recorded = LocationSummary(
        activities: [
          TimelineActivity(
            startTime: t(10),
            endTime: t(11),
            type: TravelModes.walking,
            distanceMeters: 500,
            source: TimelineSource.device,
          ),
        ],
        placeVisits: [
          TimelinePlaceVisit(
            startTime: t(11),
            endTime: t(14),
            name: 'Home',
            source: TimelineSource.device,
          ),
        ],
      );
      final merged = mergeLocationSources(imported, recorded);
      expect(merged.activities, hasLength(1));
      final visit = merged.placeVisits.single;
      expect(visit.startTime, t(12));
      expect(visit.sourceStart, t(11));
    });
  });
}
