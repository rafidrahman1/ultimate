import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_profile.dart';

enum LocationEditKind {
  /// A trip's travel mode.
  mode,

  /// Which place a visit was at.
  place,

  /// When a visit or trip started and ended.
  times,

  /// Not a real visit / trip. Removing a visit joins the trips either side.
  remove,
}

/// One correction you made to the timeline.
///
/// It names the entry by the times it was detected with ([matchStart],
/// [matchEnd]) rather than an id, so it keeps applying when the recorder
/// re-processes the day or a new Google export replaces the entry.
class LocationEdit {
  const LocationEdit({
    required this.id,
    required this.kind,
    required this.isVisit,
    required this.matchStart,
    required this.matchEnd,
    this.type,
    this.avgKmh,
    this.placeId,
    this.placeName,
    this.semanticType,
    this.point,
    this.newStart,
    this.newEnd,
  });

  final String id;
  final LocationEditKind kind;

  /// Applies to a visit (true) or a trip (false).
  final bool isVisit;
  final DateTime matchStart;
  final DateTime matchEnd;

  /// [LocationEditKind.mode]: the right mode, and the trip's average speed
  /// so the mode classifier can learn from it.
  final String? type;
  final double? avgKmh;

  /// [LocationEditKind.place]: the place it really was.
  final String? placeId;
  final String? placeName;
  final String? semanticType;
  final GeoPoint? point;

  /// [LocationEditKind.times].
  final DateTime? newStart;
  final DateTime? newEnd;

  /// True when this edit is about the entry detected over `[start, end]`:
  /// each one's midpoint falls inside the other.
  bool matches(DateTime start, DateTime end, {required bool visit}) {
    if (visit != isVisit) return false;
    final mid = _mid(start, end);
    final ownMid = _mid(matchStart, matchEnd);
    return !mid.isBefore(matchStart) &&
        !mid.isAfter(matchEnd) &&
        !ownMid.isBefore(start) &&
        !ownMid.isAfter(end);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'visit': isVisit,
    'from': matchStart.toUtc().toIso8601String(),
    'to': matchEnd.toUtc().toIso8601String(),
    if (type != null) 'type': type,
    if (avgKmh != null) 'kmh': avgKmh,
    if (placeId != null) 'placeId': placeId,
    if (placeName != null) 'placeName': placeName,
    if (semanticType != null) 'semantic': semanticType,
    if (point != null) 'at': '${point!.latitude},${point!.longitude}',
    if (newStart != null) 'newFrom': newStart!.toUtc().toIso8601String(),
    if (newEnd != null) 'newTo': newEnd!.toUtc().toIso8601String(),
  };

  static LocationEdit? fromJson(Map<String, dynamic> json) {
    final kind = LocationEditKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final from = DateTime.tryParse(json['from']?.toString() ?? '');
    final to = DateTime.tryParse(json['to']?.toString() ?? '');
    final id = json['id'] as String?;
    if (kind == null || from == null || to == null || id == null) return null;
    DateTime? time(Object? raw) =>
        raw == null ? null : DateTime.tryParse(raw.toString());
    return LocationEdit(
      id: id,
      kind: kind,
      isVisit: json['visit'] == true,
      matchStart: from,
      matchEnd: to,
      type: json['type'] as String?,
      avgKmh: (json['kmh'] as num?)?.toDouble(),
      placeId: json['placeId'] as String?,
      placeName: json['placeName'] as String?,
      semanticType: json['semantic'] as String?,
      point: parseGeoPoint(json['at']),
      newStart: time(json['newFrom']),
      newEnd: time(json['newTo']),
    );
  }
}

DateTime _mid(DateTime a, DateTime b) =>
    a.add(Duration(microseconds: b.difference(a).inMicroseconds ~/ 2));

/// What a place is, as you set it.
enum PlaceKindOverride { home, work, other }

/// Every correction, plus places you marked as home / work / neither.
class LocationEdits {
  const LocationEdits({this.edits = const [], this.placeKinds = const {}});

  static const empty = LocationEdits();

  final List<LocationEdit> edits;
  final Map<String, PlaceKindOverride> placeKinds;

  bool get isEmpty => edits.isEmpty && placeKinds.isEmpty;

  Map<String, dynamic> toJson() => {
    'edits': [for (final e in edits) e.toJson()],
    'placeKinds': {for (final e in placeKinds.entries) e.key: e.value.name},
  };

  static LocationEdits fromJson(Map<String, dynamic> json) {
    final edits = <LocationEdit>[];
    for (final raw in (json['edits'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final edit = LocationEdit.fromJson(raw.cast<String, dynamic>());
      if (edit != null) edits.add(edit);
    }
    final kinds = <String, PlaceKindOverride>{};
    final rawKinds = json['placeKinds'];
    if (rawKinds is Map) {
      rawKinds.forEach((id, value) {
        final kind = PlaceKindOverride.values
            .where((k) => k.name == value)
            .firstOrNull;
        if (kind != null) kinds[id.toString()] = kind;
      });
    }
    return LocationEdits(edits: edits, placeKinds: kinds);
  }
}

/// Applies [edits] to [summary]: removals first (joining the trips around a
/// removed visit), then mode, place and time changes, then home / work marks.
LocationSummary applyLocationEdits(
  LocationSummary summary,
  LocationEdits edits,
) {
  if (edits.isEmpty) return summary;
  final removals = [
    for (final e in edits.edits)
      if (e.kind == LocationEditKind.remove) e,
  ];
  final changes = [
    for (final e in edits.edits)
      if (e.kind != LocationEditKind.remove) e,
  ];

  // 1. Removals.
  final removedVisits = <(TimelinePlaceVisit, LocationEdit)>[];
  final visits = <TimelinePlaceVisit>[];
  for (final visit in summary.placeVisits) {
    final removal = removals
        .where(
          (e) => e.matches(visit.sourceStart, visit.sourceEnd, visit: true),
        )
        .firstOrNull;
    if (removal == null) {
      visits.add(visit);
    } else if (!visit.isNested) {
      removedVisits.add((visit, removal));
    }
  }
  var activities = [
    for (final activity in summary.activities)
      if (!removals.any(
        (e) =>
            e.matches(activity.sourceStart, activity.sourceEnd, visit: false),
      ))
        activity,
  ];
  for (final (visit, removal) in removedVisits) {
    activities = _joinAround(activities, visit, removal.id);
  }

  // 2. Changes, oldest edit first so a later one wins.
  List<LocationEdit> editsFor(DateTime start, DateTime end, bool visit) => [
    for (final e in changes)
      if (e.matches(start, end, visit: visit)) e,
  ];

  final editedActivities = <TimelineActivity>[];
  for (final activity in activities) {
    var result = activity;
    for (final edit in editsFor(
      activity.sourceStart,
      activity.sourceEnd,
      false,
    )) {
      result = switch (edit.kind) {
        LocationEditKind.mode when edit.type != null => result.copyWith(
          type: edit.type,
        ),
        LocationEditKind.times => result.copyWith(
          startTime: edit.newStart,
          endTime: edit.newEnd,
        ),
        _ => result,
      };
      result = result.copyWith(editIds: [...result.editIds, edit.id]);
    }
    editedActivities.add(result);
  }

  final editedVisits = <TimelinePlaceVisit>[];
  for (final visit in visits) {
    var result = visit;
    for (final edit in editsFor(visit.sourceStart, visit.sourceEnd, true)) {
      result = switch (edit.kind) {
        LocationEditKind.place when edit.placeId != null => result.copyWith(
          placeId: edit.placeId,
          point: edit.point,
          name:
              edit.placeName ?? _labelFor(edit.semanticType) ?? 'Unnamed place',
          semanticType: () => edit.semanticType,
        ),
        LocationEditKind.times => result.copyWith(
          startTime: edit.newStart,
          endTime: edit.newEnd,
        ),
        _ => result,
      };
      result = result.copyWith(editIds: [...result.editIds, edit.id]);
    }
    editedVisits.add(result);
  }

  // 3. Home / work marks.
  final marked = [
    for (final visit in editedVisits)
      switch (edits.placeKinds[visit.placeId]) {
        null => visit,
        final kind => visit.copyWith(
          semanticType: () => _semanticFor(kind),
          name:
              _labelFor(_semanticFor(kind)) ??
              (visit.name == 'Home' || visit.name == 'Work'
                  ? 'Unnamed place'
                  : null),
        ),
      },
  ]..sort((a, b) => a.startTime.compareTo(b.startTime));
  editedActivities.sort((a, b) => a.startTime.compareTo(b.startTime));

  return LocationSummary(
    activities: editedActivities,
    placeVisits: marked,
    profile: _profileWithMarks(summary.profile, marked, edits.placeKinds),
    trips: summary.trips,
    placeNames: summary.placeNames,
    isLegacyCache: summary.isLegacyCache,
    fileName: summary.fileName,
  );
}

String? _semanticFor(PlaceKindOverride kind) => switch (kind) {
  PlaceKindOverride.home => 'TYPE_HOME',
  PlaceKindOverride.work => 'TYPE_WORK',
  PlaceKindOverride.other => null,
};

String? _labelFor(String? semanticType) => switch (semanticType) {
  'TYPE_HOME' || 'TYPE_INFERRED_HOME' => 'Home',
  'TYPE_WORK' || 'TYPE_INFERRED_WORK' => 'Work',
  _ => null,
};

/// The trip that ended at [visit] and the one that left it become one trip.
List<TimelineActivity> _joinAround(
  List<TimelineActivity> activities,
  TimelinePlaceVisit visit,
  String editId,
) {
  const slack = Duration(minutes: 10);
  final before = activities.indexWhere(
    (a) => a.endTime.difference(visit.startTime).abs() <= slack,
  );
  final after = activities.indexWhere(
    (a) => a.startTime.difference(visit.endTime).abs() <= slack,
  );
  if (before < 0 || after < 0 || before == after) return activities;
  final a = activities[before];
  final b = activities[after];
  final joined = TimelineActivity(
    startTime: a.startTime,
    endTime: b.endTime,
    type: a.distanceMeters >= b.distanceMeters ? a.type : b.type,
    distanceMeters: a.distanceMeters + b.distanceMeters,
    probability: a.probability,
    source: a.source,
    editIds: {...a.editIds, ...b.editIds, editId}.toList(),
    sourceStart: a.sourceStart,
    sourceEnd: b.sourceEnd,
  );
  return [
    for (var i = 0; i < activities.length; i++)
      if (i == before) joined else if (i != after) activities[i],
  ];
}

/// Moves the profile's Home / Work to the places you marked.
LocationProfile _profileWithMarks(
  LocationProfile profile,
  List<TimelinePlaceVisit> visits,
  Map<String, PlaceKindOverride> kinds,
) {
  if (kinds.isEmpty) return profile;
  GeoPoint? pointOf(String id) => visits
      .where((v) => v.placeId == id && v.point != null)
      .firstOrNull
      ?.point;

  var places = List<ProfilePlace>.of(profile.places);
  void relabel(String label, String id, GeoPoint point) {
    places = [
      for (final p in places)
        if (p.label?.toUpperCase() == label)
          ProfilePlace(placeId: p.placeId, point: p.point)
        else
          p,
      ProfilePlace(placeId: id, point: point, label: label),
    ];
  }

  kinds.forEach((id, kind) {
    final point = pointOf(id);
    if (point == null) return;
    switch (kind) {
      case PlaceKindOverride.home:
        relabel('HOME', id, point);
      case PlaceKindOverride.work:
        relabel('WORK', id, point);
      case PlaceKindOverride.other:
        places = [
          for (final p in places)
            if (p.label != null && p.point.distanceTo(point) <= 150)
              ProfilePlace(placeId: p.placeId, point: p.point)
            else
              p,
        ];
    }
  });
  return LocationProfile(
    places: places,
    trips: profile.trips,
    modeAffinities: profile.modeAffinities,
  );
}
