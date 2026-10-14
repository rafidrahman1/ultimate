part of 'place_stats.dart';

/// A place's first-ever visit also counts visits under other ids at the same
/// spot, so a shop Google re-identified isn't reported as new.
PlaceStat _withNearbyHistory(
  PlaceStat place,
  Map<String, DateTime> firstEver,
  Map<String, GeoPoint> pointOf,
) {
  var earliest = place.firstEver;
  final here = place.point;
  if (place.kind == PlaceKind.other && here != null) {
    pointOf.forEach((id, point) {
      if (point.distanceTo(here) > _mergeMeters) return;
      final seen = firstEver[id];
      if (seen != null && (earliest == null || seen.isBefore(earliest!))) {
        earliest = seen;
      }
    });
  }
  return PlaceStat(
    placeId: place.placeId,
    placeIds: place.placeIds,
    kind: place.kind,
    point: place.point,
    visits: place.visits,
    totalDwell: place.totalDwell,
    firstSeen: place.firstSeen,
    lastSeen: place.lastSeen,
    firstEver: earliest,
  );
}

/// What to call [place]: the user's name, else Home/Work, else generic.
String placeDisplayName(PlaceStat place, Map<String, String> names) {
  for (final id in place.placeIds) {
    final custom = names[id];
    if (custom != null && custom.isNotEmpty) return custom;
  }
  return switch (place.kind) {
    PlaceKind.home => 'Home',
    PlaceKind.work => 'Work',
    PlaceKind.other => 'Unnamed place',
  };
}

/// Places closer than this are the same physical place.
const _mergeMeters = 75.0;

/// Collapses ids that are the same place: every home id into one, every work
/// id into one, and other places within [_mergeMeters] of a busier one.
List<PlaceStat> mergePlaces(List<PlaceStat> places) {
  PlaceStat combine(PlaceStat into, PlaceStat other) {
    DateTime? earlier(DateTime? a, DateTime? b) =>
        a == null ? b : (b == null || a.isBefore(b) ? a : b);
    return PlaceStat(
      placeId: into.placeId,
      placeIds: [...into.placeIds, ...other.placeIds],
      kind: into.kind,
      point: into.point,
      visits: into.visits + other.visits,
      totalDwell: into.totalDwell + other.totalDwell,
      firstSeen: into.firstSeen.isBefore(other.firstSeen)
          ? into.firstSeen
          : other.firstSeen,
      lastSeen: into.lastSeen.isAfter(other.lastSeen)
          ? into.lastSeen
          : other.lastSeen,
      firstEver: earlier(into.firstEver, other.firstEver),
    );
  }

  final byWeight = List<PlaceStat>.of(places)
    ..sort((a, b) => b.totalDwell.compareTo(a.totalDwell));
  final merged = <PlaceStat>[];
  for (final place in byWeight) {
    var index = -1;
    for (var i = 0; i < merged.length; i++) {
      final target = merged[i];
      final sameLabel =
          place.kind != PlaceKind.other && place.kind == target.kind;
      final near =
          place.kind == PlaceKind.other &&
          target.kind == PlaceKind.other &&
          place.point != null &&
          target.point != null &&
          place.point!.distanceTo(target.point!) <= _mergeMeters;
      if (sameLabel || near) {
        index = i;
        break;
      }
    }
    if (index < 0) {
      merged.add(place);
    } else {
      merged[index] = combine(merged[index], place);
    }
  }
  return merged;
}

class _Acc {
  _Acc(this.kind, this.point, this.first) : last = first;

  final PlaceKind kind;
  final GeoPoint? point;
  int visits = 0;
  Duration dwell = Duration.zero;
  DateTime first;
  DateTime last;
}

/// Pairs each home visit's end with the next work visit's start (and the
/// reverse) when they fall within [_maxCommute] of each other.
CommuteStats _commutes(
  List<TimelinePlaceVisit> sorted,
  PlaceKind Function(TimelinePlaceVisit) kindOf,
) {
  final toWork = <CommuteSample>[];
  final toHome = <CommuteSample>[];
  final seenWorkDays = <String>{};
  final seenHomeDays = <String>{};

  for (var i = 0; i + 1 < sorted.length; i++) {
    final a = sorted[i];
    final b = sorted[i + 1];
    final left = a.endTime.toLocal();
    final arrived = b.startTime.toLocal();
    final gap = arrived.difference(left);
    if (gap <= Duration.zero || gap > _maxCommute) continue;

    final from = kindOf(a);
    final to = kindOf(b);
    final day = '${arrived.year}-${arrived.month}-${arrived.day}';
    if (from == PlaceKind.home && to == PlaceKind.work) {
      // First home→work of the day only; later hops are errands.
      if (seenWorkDays.add(day)) {
        toWork.add(CommuteSample(departed: left, arrived: arrived));
      }
    } else if (from == PlaceKind.work && to == PlaceKind.home) {
      if (seenHomeDays.add(day)) {
        toHome.add(CommuteSample(departed: left, arrived: arrived));
      }
    }
  }
  return CommuteStats(toWork: toWork, toHome: toHome);
}
