import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_profile.dart';
import 'package:personal/features/location/recording/timeline_segmenter.dart';
import 'package:personal/features/location/recording/travel_mode_classifier.dart';

/// A recorded stay closer than this to a known place was at that place.
const placeMatchMeters = 100.0;

/// A place seen before: in the Google history, or made by the recorder.
class KnownPlace {
  const KnownPlace({
    required this.id,
    required this.point,
    this.semanticType,
    this.visits = 0,
  });

  final String id;
  final GeoPoint point;
  final String? semanticType;
  final int visits;

  bool get isLabelled => semanticType != null;
}

/// One entry per place id in [visits] (the Google history), with the label
/// most of its visits carry, plus the profile's Home and Work.
List<KnownPlace> knownPlacesFrom(
  List<TimelinePlaceVisit> visits, {
  LocationProfile profile = LocationProfile.empty,
}) {
  final points = <String, GeoPoint>{};
  final labels = <String, Map<String, int>>{};
  final counts = <String, int>{};
  for (final visit in visits) {
    final id = visit.placeId;
    final point = visit.point;
    if (id == null || point == null || visit.isNested) continue;
    points.putIfAbsent(id, () => point);
    counts.update(id, (n) => n + 1, ifAbsent: () => 1);
    final type = switch (visit.semanticType) {
      'TYPE_HOME' || 'TYPE_INFERRED_HOME' => 'TYPE_HOME',
      'TYPE_WORK' || 'TYPE_INFERRED_WORK' => 'TYPE_WORK',
      _ => '',
    };
    labels
        .putIfAbsent(id, () => {})
        .update(type, (n) => n + 1, ifAbsent: () => 1);
  }
  final places = <KnownPlace>[
    for (final entry in points.entries)
      KnownPlace(
        id: entry.key,
        point: entry.value,
        semanticType: _majority(labels[entry.key]),
        visits: counts[entry.key] ?? 0,
      ),
  ];
  for (final place in profile.places) {
    final type = switch (place.label?.toUpperCase()) {
      'HOME' => 'TYPE_HOME',
      'WORK' => 'TYPE_WORK',
      _ => null,
    };
    if (type == null) continue;
    places.add(
      KnownPlace(id: place.placeId, point: place.point, semanticType: type),
    );
  }
  return places;
}

String? _majority(Map<String, int>? tally) {
  if (tally == null || tally.isEmpty) return null;
  final best = tally.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return best.key.isEmpty ? null : best.key;
}

class _DevicePlace {
  _DevicePlace(this.id, this.lat, this.lng);

  final String id;
  double lat;
  double lng;
  int count = 1;

  GeoPoint get point => GeoPoint(lat, lng);

  void add(GeoPoint p) {
    count++;
    lat += (p.latitude - lat) / count;
    lng += (p.longitude - lng) / count;
  }
}

/// Turns recorded segments into visits and trips the rest of the app reads,
/// in the same shape as a Google export.
///
/// A stay at a place you've been before reuses that place's id, so names you
/// gave it and its Home / Work label carry over. A new spot gets an id of its
/// own (`dev:…`), stable across rebuilds because it comes from the first
/// visit's start time.
LocationSummary buildRecordedSummary({
  required List<RecordedSegment> segments,
  required List<KnownPlace> knownPlaces,
  required TravelModeClassifier classifier,
  Set<String> namedPlaceIds = const {},
}) {
  final devicePlaces = <_DevicePlace>[];
  final visits = <TimelinePlaceVisit>[];
  final activities = <TimelineActivity>[];

  for (final segment in segments) {
    if (segment.isVisit) {
      final center = segment.center;
      if (center == null) continue;
      final known = _bestKnown(center, knownPlaces, namedPlaceIds);
      String id;
      GeoPoint point;
      String? semantic;
      if (known != null) {
        id = known.id;
        point = known.point;
        semantic = known.semanticType;
      } else {
        final device = _nearestDevice(center, devicePlaces);
        if (device != null) {
          device.add(center);
          id = device.id;
        } else {
          id = 'dev:${segment.startMs.toRadixString(36)}';
          devicePlaces.add(_DevicePlace(id, center.latitude, center.longitude));
        }
        point = center;
      }
      visits.add(
        TimelinePlaceVisit(
          startTime: segment.start,
          endTime: segment.end,
          name: _labelFor(semantic) ?? 'Unnamed place',
          semanticType: semantic,
          placeId: id,
          point: point,
          source: TimelineSource.device,
        ),
      );
    } else {
      activities.add(
        TimelineActivity(
          startTime: segment.start,
          endTime: segment.end,
          type: classifier.classify(
            avgKmh: segment.avgKmh,
            activity: segment.activity,
          ),
          distanceMeters: segment.distanceMeters,
          source: TimelineSource.device,
        ),
      );
    }
  }

  final hasHome = knownPlaces.any((p) => p.semanticType == 'TYPE_HOME');
  final hasWork = knownPlaces.any((p) => p.semanticType == 'TYPE_WORK');
  final inferred = _inferHomeWork(
    visits,
    inferHome: !hasHome,
    inferWork: !hasWork,
  );
  final labelled = [
    for (final visit in visits)
      switch (inferred[visit.placeId]) {
        null => visit,
        final type => visit.copyWith(
          semanticType: () => type,
          name: _labelFor(type),
        ),
      },
  ];

  final profilePlaces = <ProfilePlace>[];
  inferred.forEach((id, type) {
    final point = labelled.firstWhere((v) => v.placeId == id).point;
    if (point == null) return;
    profilePlaces.add(
      ProfilePlace(
        placeId: id,
        point: point,
        label: type == 'TYPE_INFERRED_HOME' ? 'HOME' : 'WORK',
      ),
    );
  });

  return LocationSummary(
    activities: activities,
    placeVisits: labelled,
    profile: LocationProfile(places: profilePlaces),
  );
}

String? _labelFor(String? semanticType) => switch (semanticType) {
  'TYPE_HOME' || 'TYPE_INFERRED_HOME' => 'Home',
  'TYPE_WORK' || 'TYPE_INFERRED_WORK' => 'Work',
  _ => null,
};

/// Among known places within reach: one you named, else Home / Work, else
/// the nearest.
KnownPlace? _bestKnown(
  GeoPoint center,
  List<KnownPlace> places,
  Set<String> named,
) {
  KnownPlace? best;
  var bestRank = -1;
  var bestDistance = double.infinity;
  for (final place in places) {
    final distance = place.point.distanceTo(center);
    if (distance > placeMatchMeters) continue;
    final rank = named.contains(place.id) ? 2 : (place.isLabelled ? 1 : 0);
    if (rank > bestRank || (rank == bestRank && distance < bestDistance)) {
      best = place;
      bestRank = rank;
      bestDistance = distance;
    }
  }
  return best;
}

_DevicePlace? _nearestDevice(GeoPoint center, List<_DevicePlace> places) {
  _DevicePlace? best;
  var bestDistance = placeMatchMeters;
  for (final place in places) {
    final distance = place.point.distanceTo(center);
    if (distance <= bestDistance) {
      best = place;
      bestDistance = distance;
    }
  }
  return best;
}

/// With no history saying where home and work are: home is where most nights
/// are spent, work where most daytime away from home is.
Map<String, String> _inferHomeWork(
  List<TimelinePlaceVisit> visits, {
  required bool inferHome,
  required bool inferWork,
}) {
  if (!inferHome && !inferWork) return const {};
  final nights = <String, Set<DateTime>>{};
  final days = <String, Map<DateTime, Duration>>{};
  for (final visit in visits) {
    final id = visit.placeId;
    if (id == null) continue;
    var cursor = visit.startTime.toLocal();
    final end = visit.endTime.toLocal();
    while (cursor.isBefore(end)) {
      final day = DateTime(cursor.year, cursor.month, cursor.day);
      final next = day.add(const Duration(days: 1));
      final sliceEnd = end.isBefore(next) ? end : next;
      // 01:00–05:00 counts as a night there.
      final nightStart = day.add(const Duration(hours: 1));
      final nightEnd = day.add(const Duration(hours: 5));
      if (cursor.isBefore(nightEnd) && sliceEnd.isAfter(nightStart)) {
        nights.putIfAbsent(id, () => {}).add(day);
      }
      final dayStart = day.add(const Duration(hours: 9));
      final dayEnd = day.add(const Duration(hours: 17));
      final a = cursor.isAfter(dayStart) ? cursor : dayStart;
      final b = sliceEnd.isBefore(dayEnd) ? sliceEnd : dayEnd;
      if (b.isAfter(a)) {
        days
            .putIfAbsent(id, () => {})
            .update(
              day,
              (d) => d + b.difference(a),
              ifAbsent: () => b.difference(a),
            );
      }
      cursor = sliceEnd;
    }
  }

  final result = <String, String>{};
  String? home;
  if (nights.isNotEmpty) {
    final best = nights.entries.reduce(
      (a, b) => a.value.length >= b.value.length ? a : b,
    );
    if (best.value.length >= 3) home = best.key;
  }
  if (inferHome && home != null) result[home] = 'TYPE_INFERRED_HOME';

  if (inferWork) {
    MapEntry<String, int>? best;
    days.forEach((id, perDay) {
      if (id == home) return;
      final workDays = perDay.values.where((d) => d.inHours >= 3).length;
      if (workDays >= 3 && (best == null || workDays > best!.value)) {
        best = MapEntry(id, workDays);
      }
    });
    if (best != null) result[best!.key] = 'TYPE_INFERRED_WORK';
  }
  return result;
}
