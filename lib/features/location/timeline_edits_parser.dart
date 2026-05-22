import 'dart:convert';

import 'timeline_entry.dart';

List<TimelineEntry> parseTimelineEditsJson(String jsonString) {
  final root = jsonDecode(jsonString);
  if (root is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object at the root');
  }

  final edits = root['timelineEdits'];
  if (edits is! List) {
    throw const FormatException('Missing or invalid "timelineEdits" array');
  }

  final entries = <TimelineEntry>[];
  for (final edit in edits) {
    if (edit is! Map<String, dynamic>) continue;
    final segment = edit['inferredSemanticSegment'];
    if (segment is Map<String, dynamic>) {
      final entry = _parseSemanticSegment(segment);
      if (entry != null) entries.add(entry);
    }
  }

  entries.sort((a, b) => b.startTime.compareTo(a.startTime));
  return entries;
}

TimelineEntry? _parseSemanticSegment(Map<String, dynamic> segment) {
  final startTime = _parseDateTime(segment['startTime']);
  final endTime = _parseDateTime(segment['endTime']);
  if (startTime == null || endTime == null) return null;

  final inner = segment['segment'];
  if (inner is! Map<String, dynamic>) return null;

  final visit = inner['visit'];
  if (visit is Map<String, dynamic>) {
    return _parseVisit(visit, startTime, endTime);
  }

  final activity = inner['activity'];
  if (activity is Map<String, dynamic>) {
    return _parseActivity(activity, startTime, endTime);
  }

  return null;
}

TimelineEntry? _parseVisit(
  Map<String, dynamic> visit,
  DateTime startTime,
  DateTime endTime,
) {
  final top = visit['topCandidate'];
  if (top is! Map<String, dynamic>) return null;

  final location = top['placeLocation'];
  final coords = _coordsFromMap(location is Map<String, dynamic> ? location : null);
  if (coords == null) return null;

  final semanticType = top['semanticType'] as String? ?? 'UNKNOWN';
  final placeId = top['placeId'] as String?;

  return TimelineEntry(
    kind: TimelineEntryKind.visit,
    startTime: startTime,
    endTime: endTime,
    title: formatTimelineLabel(semanticType),
    subtitle: placeId != null ? 'Place $placeId' : 'Visit',
    latitude: coords.$1,
    longitude: coords.$2,
    placeId: placeId,
    visitType: semanticType,
  );
}

TimelineEntry? _parseActivity(
  Map<String, dynamic> activity,
  DateTime startTime,
  DateTime endTime,
) {
  final top = activity['topCandidate'];
  final type = top is Map<String, dynamic>
      ? top['type'] as String? ?? 'ACTIVITY'
      : 'ACTIVITY';

  final start = _coordsFromMap(
    activity['start'] is Map<String, dynamic>
        ? activity['start'] as Map<String, dynamic>
        : null,
  );
  final endCoords = _coordsFromMap(
    activity['end'] is Map<String, dynamic>
        ? activity['end'] as Map<String, dynamic>
        : null,
  );

  final latitude = endCoords?.$1 ?? start?.$1;
  final longitude = endCoords?.$2 ?? start?.$2;
  if (latitude == null || longitude == null) return null;

  final distance = (activity['distanceMeters'] as num?)?.toDouble();

  return TimelineEntry(
    kind: TimelineEntryKind.activity,
    startTime: startTime,
    endTime: endTime,
    title: formatTimelineLabel(type),
    subtitle: distance != null
        ? '${(distance / 1000).toStringAsFixed(1)} km'
        : 'Trip',
    latitude: latitude,
    longitude: longitude,
    distanceMeters: distance,
    activityType: type,
  );
}

(double, double)? _coordsFromMap(Map<String, dynamic>? map) {
  if (map == null) return null;
  final latE7 = map['latE7'];
  final lngE7 = map['lngE7'];
  if (latE7 is! num || lngE7 is! num) return null;
  return (latE7 / 1e7, lngE7 / 1e7);
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

