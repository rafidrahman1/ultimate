import 'dart:convert';

import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_profile.dart';

/// Writes [summary] in the Google Maps Timeline export format
/// (`semanticSegments` + `userLocationProfile`), so the file reads back with
/// [parseTimelineExport] and looks like the export Google gives you.
///
/// Place names are written too (Google's on-device export has none); a name
/// you gave a place in [placeNames] wins over the detected one.
Map<String, dynamic> timelineExportJson(
  LocationSummary summary, {
  Map<String, String> placeNames = const {},
}) {
  final segments = <({DateTime start, Map<String, dynamic> json})>[
    for (final v in summary.placeVisits)
      (start: v.startTime, json: _visitJson(v, placeNames)),
    for (final a in summary.activities)
      (start: a.startTime, json: _activityJson(a)),
    for (final t in summary.trips) (start: t.startTime, json: _tripJson(t)),
  ]..sort((a, b) => a.start.compareTo(b.start));

  return {
    'semanticSegments': [for (final s in segments) s.json],
    if (!summary.profile.isEmpty)
      'userLocationProfile': _profileJson(summary.profile),
  };
}

String encodeTimelineExport(
  LocationSummary summary, {
  Map<String, String> placeNames = const {},
}) => jsonEncode(timelineExportJson(summary, placeNames: placeNames));

Map<String, dynamic> _visitJson(
  TimelinePlaceVisit v,
  Map<String, String> placeNames,
) {
  final given = v.placeId == null ? null : placeNames[v.placeId];
  final name = (given != null && given.isNotEmpty) ? given : v.name;
  return {
    'startTime': timelineTimestamp(v.startTime),
    'endTime': timelineTimestamp(v.endTime),
    'visit': {
      'hierarchyLevel': v.level,
      'probability': ?v.probability,
      'topCandidate': {
        'placeId': ?v.placeId,
        'semanticType': v.semanticType ?? 'UNKNOWN',
        if (name != 'Unknown place') 'name': name,
        'address': ?v.address,
        if (v.point != null) 'placeLocation': {'latLng': _latLng(v.point!)},
      },
    },
  };
}

Map<String, dynamic> _activityJson(TimelineActivity a) => {
  'startTime': timelineTimestamp(a.startTime),
  'endTime': timelineTimestamp(a.endTime),
  'activity': {
    'distanceMeters': a.distanceMeters,
    'topCandidate': {'type': a.type, 'probability': ?a.probability},
  },
};

Map<String, dynamic> _tripJson(TimelineTrip t) => {
  'startTime': timelineTimestamp(t.startTime),
  'endTime': timelineTimestamp(t.endTime),
  'timelineMemory': {
    'trip': {
      'distanceFromOriginKms': t.distanceFromOriginKm,
      'destinations': [
        for (final id in t.destinationPlaceIds)
          {
            'identifier': {'placeId': id},
          },
      ],
    },
  },
};

Map<String, dynamic> _profileJson(LocationProfile profile) => {
  'frequentPlaces': [
    for (final p in profile.places)
      {
        'placeId': p.placeId,
        'placeLocation': _latLng(p.point),
        'label': ?p.label,
      },
  ],
  'frequentTrips': [
    for (final t in profile.trips)
      {
        // Minutes since Monday 00:00.
        'startTimeMinutes': (t.weekday - 1) * 1440 + t.startMinutes,
        'durationMinutes': t.durationMinutes,
        'confidence': ?t.confidence,
        'commuteDirection': ?_direction(t.direction),
        'modeDistribution': [
          for (final e in t.modeShares.entries)
            {'mode': e.key, 'rate': e.value},
        ],
      },
  ],
  if (profile.modeAffinities.isNotEmpty)
    'persona': {
      'travelModeAffinities': [
        for (final e in profile.modeAffinities.entries)
          {'mode': e.key, 'affinity': e.value},
      ],
    },
};

String? _direction(CommuteDirection d) => switch (d) {
  CommuteDirection.homeToWork => 'HOME_TO_WORK',
  CommuteDirection.workToHome => 'WORK_TO_HOME',
  CommuteDirection.other => null,
};

String _latLng(GeoPoint p) => '${p.latitude}°, ${p.longitude}°';

/// Local time with its UTC offset, as Google writes it:
/// `2026-11-26T08:05:00.000+06:00`.
String timelineTimestamp(DateTime time) {
  final local = time.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.toIso8601String()}$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
}
