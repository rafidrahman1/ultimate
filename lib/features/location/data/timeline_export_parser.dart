part of 'timeline_activity.dart';

/// Parses a whole export in one pass: one `jsonDecode`, all four sections.
LocationSummary parseTimelineExport(String rawJson, {String? fileName}) {
  final root = _decodeRoot(rawJson);
  return LocationSummary(
    activities: _activitiesFromRoot(root),
    placeVisits: _placeVisitsFromRoot(root),
    profile: parseTimelineProfile(root),
    trips: parseTimelineTrips(root),
    fileName: fileName,
  );
}

/// [parseTimelineExport] off the UI isolate. A multi-year export is tens of
/// megabytes, which freezes the app for seconds if decoded on the main thread.
Future<LocationSummary> parseTimelineExportInBackground(
  Uint8List bytes, {
  String? fileName,
}) {
  return Isolate.run(
    () => parseTimelineExport(utf8.decode(bytes), fileName: fileName),
  );
}

List<TimelineActivity> parseTimelineJsonActivities(String rawJson) =>
    _activitiesFromRoot(_decodeRoot(rawJson));

List<TimelinePlaceVisit> parseTimelineJsonPlaceVisits(String rawJson) =>
    _placeVisitsFromRoot(_decodeRoot(rawJson));

List<TimelineActivity> _activitiesFromRoot(Map<String, dynamic> decoded) {
  final segments = decoded['semanticSegments'];
  if (segments is! List) return const [];

  final activities = <TimelineActivity>[];
  for (final item in segments) {
    if (item is! Map) continue;
    final activity = item['activity'];
    if (activity is! Map) continue;

    final startTimeRaw = item['startTime'];
    final endTimeRaw = item['endTime'];
    final distanceRaw = activity['distanceMeters'];
    final topCandidate = activity['topCandidate'];
    final typeRaw = topCandidate is Map ? topCandidate['type'] : null;
    final probabilityRaw = topCandidate is Map
        ? topCandidate['probability']
        : null;

    final startTime = _parseDate(startTimeRaw);
    final endTime = _parseDate(endTimeRaw);
    final distance = _parseDouble(distanceRaw);
    final type = typeRaw?.toString();

    if (startTime == null ||
        endTime == null ||
        distance == null ||
        distance <= 0 ||
        type == null ||
        type.isEmpty) {
      continue;
    }

    activities.add(
      TimelineActivity(
        startTime: startTime,
        endTime: endTime,
        type: type,
        distanceMeters: distance,
        probability: _parseDouble(probabilityRaw),
      ),
    );
  }
  return activities;
}

List<TimelinePlaceVisit> _placeVisitsFromRoot(Map<String, dynamic> decoded) {
  final segments = decoded['semanticSegments'];
  if (segments is! List) return const [];

  final visits = <TimelinePlaceVisit>[];
  for (final item in segments) {
    if (item is! Map) continue;
    final placeVisit = item['visit'] ?? item['placeVisit'];
    if (placeVisit is! Map) continue;

    final startTime = _parseDate(item['startTime']);
    final endTime = _parseDate(item['endTime']);
    final topCandidate = placeVisit['topCandidate'];
    final location = placeVisit['location'];
    final placeNameRaw = _firstNonEmptyString([
      if (topCandidate is Map) topCandidate['name'],
      if (location is Map) location['name'],
    ]);
    final addressRaw = _firstNonEmptyString([
      if (topCandidate is Map) topCandidate['address'],
      if (location is Map) location['address'],
    ]);
    final semanticType = _normalizeSemanticType(
      _firstNonEmptyString([
        if (topCandidate is Map) topCandidate['semanticType'],
        if (location is Map) location['semanticType'],
        placeVisit['semanticType'],
      ]),
    );
    final placeName = placeNameRaw?.trim();
    final address = addressRaw?.trim();

    if (startTime == null || endTime == null) continue;
    final placeId = _firstNonEmptyString([
      if (topCandidate is Map) topCandidate['placeId'],
      if (location is Map) location['placeId'],
    ]);
    final point = parseGeoPoint(
      _firstNonEmptyString([
        if (topCandidate is Map && topCandidate['placeLocation'] is Map)
          (topCandidate['placeLocation'] as Map)['latLng'],
      ]),
    );
    // A visit with no name, no type and no place id tells us nothing.
    if ((placeName == null || placeName.isEmpty) &&
        semanticType == null &&
        placeId == null) {
      continue;
    }

    visits.add(
      TimelinePlaceVisit(
        startTime: startTime,
        endTime: endTime,
        name:
            placeName ?? _labelForSemanticType(semanticType) ?? 'Unknown place',
        address: address == null || address.isEmpty ? null : address,
        semanticType: semanticType,
        placeId: placeId,
        point: point,
        level: (placeVisit['hierarchyLevel'] as num?)?.toInt() ?? 0,
        probability: _parseDouble(
          placeVisit['probability'] ??
              (topCandidate is Map ? topCandidate['probability'] : null),
        ),
      ),
    );
  }
  return visits;
}

Map<String, dynamic> _decodeRoot(String rawJson) {
  final decoded = jsonDecode(rawJson);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Timeline JSON root must be an object.');
  }
  return decoded;
}

DateTime? _parseDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

double? _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

String? _normalizeSemanticType(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final upper = raw.toUpperCase();
  if (upper == 'UNKNOWN' || upper == 'TYPE_UNKNOWN') return null;
  if (upper.startsWith('TYPE_')) return upper;
  return 'TYPE_$upper';
}

String? _labelForSemanticType(String? semanticType) {
  return switch (semanticType) {
    'TYPE_WORK' => 'Work',
    'TYPE_HOME' => 'Home',
    _ => null,
  };
}
