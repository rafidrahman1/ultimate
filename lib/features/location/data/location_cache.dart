import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/json_file_cache.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_profile.dart';

/// Bumped when the cached location shape gains data a re-import would add.
const _locationCacheSchema = 2;
const _cacheKey = 'data_cache_location_v1';

/// Persists the last-loaded location so it survives app restarts.
abstract final class LocationCache {
  static Future<LocationSummary?> load() async {
    final map = await JsonFileCache.instance.read(_cacheKey);
    if (map == null) return null;
    try {
      return _locationFromJson(map);
    } catch (e) {
      AppLog.warn('Failed to load location cache: $e');
      return null;
    }
  }

  static Future<void> save(LocationSummary summary) async {
    if (summary.activities.isEmpty) return;
    await JsonFileCache.instance.write(_cacheKey, _locationToJson(summary));
  }

  static Future<void> clear() => JsonFileCache.instance.remove(_cacheKey);
}

Map<String, dynamic> _locationToJson(LocationSummary summary) => {
  'schema': _locationCacheSchema,
  'fileName': summary.fileName,
  'activities': summary.activities.map(_activityToJson).toList(),
  'placeVisits': summary.placeVisits.map(_placeVisitToJson).toList(),
  'profile': _profileToJson(summary.profile),
  'trips': summary.trips.map(_tripToJson).toList(),
};

LocationSummary _locationFromJson(Map<String, dynamic> json) {
  final items = json['activities'];
  final activities = items is List
      ? items
            .whereType<Map>()
            .map((e) => _activityFromJson(e.cast<String, dynamic>()))
            .toList()
      : <TimelineActivity>[];
  final placeItems = json['placeVisits'];
  final placeVisits = placeItems is List
      ? placeItems
            .whereType<Map>()
            .map((e) => _placeVisitFromJson(e.cast<String, dynamic>()))
            .toList()
      : <TimelinePlaceVisit>[];
  final tripItems = json['trips'];
  final trips = tripItems is List
      ? tripItems
            .whereType<Map>()
            .map((e) => _tripFromJson(e.cast<String, dynamic>()))
            .toList()
      : <TimelineTrip>[];
  final profileJson = json['profile'];
  return LocationSummary(
    activities: activities,
    placeVisits: placeVisits,
    profile: profileJson is Map
        ? _profileFromJson(profileJson.cast<String, dynamic>())
        : LocationProfile.empty,
    trips: trips,
    isLegacyCache: (json['schema'] as num?)?.toInt() != _locationCacheSchema,
    fileName: json['fileName'] as String?,
  );
}

String? _pointToJson(GeoPoint? p) =>
    p == null ? null : '${p.latitude},${p.longitude}';

Map<String, dynamic> _profileToJson(LocationProfile profile) => {
  'places': [
    for (final p in profile.places)
      {'id': p.placeId, 'at': _pointToJson(p.point), 'label': p.label},
  ],
  'trips': [
    for (final t in profile.trips)
      {
        'dir': t.direction.name,
        'wd': t.weekday,
        'start': t.startMinutes,
        'mins': t.durationMinutes,
        'conf': t.confidence,
        'modes': t.modeShares,
      },
  ],
  'affinities': profile.modeAffinities,
};

LocationProfile _profileFromJson(Map<String, dynamic> json) {
  final places = <ProfilePlace>[];
  for (final item in (json['places'] as List?) ?? const []) {
    if (item is! Map) continue;
    final point = parseGeoPoint(item['at']);
    final id = item['id'] as String?;
    if (point == null || id == null) continue;
    places.add(
      ProfilePlace(placeId: id, point: point, label: item['label'] as String?),
    );
  }
  final trips = <FrequentTrip>[];
  for (final item in (json['trips'] as List?) ?? const []) {
    if (item is! Map) continue;
    final modes = <String, double>{};
    final rawModes = item['modes'];
    if (rawModes is Map) {
      rawModes.forEach((k, v) {
        if (v is num) modes[k.toString()] = v.toDouble();
      });
    }
    trips.add(
      FrequentTrip(
        direction: CommuteDirection.values.firstWhere(
          (d) => d.name == item['dir'],
          orElse: () => CommuteDirection.other,
        ),
        weekday: (item['wd'] as num?)?.toInt() ?? DateTime.monday,
        startMinutes: (item['start'] as num?)?.toInt() ?? 0,
        durationMinutes: (item['mins'] as num?)?.toInt() ?? 0,
        confidence: (item['conf'] as num?)?.toDouble(),
        modeShares: modes,
      ),
    );
  }
  final affinities = <String, double>{};
  final rawAffinities = json['affinities'];
  if (rawAffinities is Map) {
    rawAffinities.forEach((k, v) {
      if (v is num) affinities[k.toString()] = v.toDouble();
    });
  }
  return LocationProfile(
    places: places,
    trips: trips,
    modeAffinities: affinities,
  );
}

Map<String, dynamic> _tripToJson(TimelineTrip trip) => {
  'start': trip.startTime.toIso8601String(),
  'end': trip.endTime.toIso8601String(),
  'km': trip.distanceFromOriginKm,
  'places': trip.destinationPlaceIds,
};

TimelineTrip _tripFromJson(Map<String, dynamic> json) => TimelineTrip(
  startTime: DateTime.parse(json['start'] as String),
  endTime: DateTime.parse(json['end'] as String),
  distanceFromOriginKm: (json['km'] as num?)?.toInt() ?? 0,
  destinationPlaceIds: [
    for (final id in (json['places'] as List?) ?? const [])
      if (id is String) id,
  ],
);

Map<String, dynamic> _activityToJson(TimelineActivity activity) => {
  'startTime': activity.startTime.toIso8601String(),
  'endTime': activity.endTime.toIso8601String(),
  'type': activity.type,
  'distanceMeters': activity.distanceMeters,
  'probability': activity.probability,
};

TimelineActivity _activityFromJson(Map<String, dynamic> json) {
  return TimelineActivity(
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    type: json['type'] as String? ?? '',
    distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
    probability: (json['probability'] as num?)?.toDouble(),
  );
}

Map<String, dynamic> _placeVisitToJson(TimelinePlaceVisit visit) => {
  'startTime': visit.startTime.toIso8601String(),
  'endTime': visit.endTime.toIso8601String(),
  'name': visit.name,
  'address': visit.address,
  'semanticType': visit.semanticType,
  'placeId': visit.placeId,
  'at': _pointToJson(visit.point),
  'level': visit.level,
  'probability': visit.probability,
};

TimelinePlaceVisit _placeVisitFromJson(Map<String, dynamic> json) {
  return TimelinePlaceVisit(
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    name: json['name'] as String? ?? 'Unknown place',
    address: json['address'] as String?,
    semanticType: json['semanticType'] as String?,
    placeId: json['placeId'] as String?,
    point: parseGeoPoint(json['at']),
    level: (json['level'] as num?)?.toInt() ?? 0,
    probability: (json['probability'] as num?)?.toDouble(),
  );
}
