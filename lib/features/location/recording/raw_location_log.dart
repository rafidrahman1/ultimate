import 'dart:convert';
import 'dart:io';

import 'package:personal/features/location/data/timeline_profile.dart';

/// One location fix written by the Android recorder.
class RawFix {
  const RawFix({
    required this.timeMs,
    required this.lat,
    required this.lng,
    this.accuracy,
    this.speed,
  });

  final int timeMs;
  final double lat;
  final double lng;

  /// Metres, 68% confidence.
  final double? accuracy;

  /// Metres per second, from GPS Doppler when available.
  final double? speed;

  GeoPoint get point => GeoPoint(lat, lng);
  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timeMs);
}

/// Android's walking / vehicle / still detection switching on or off.
class RawActivityEvent {
  const RawActivityEvent({
    required this.timeMs,
    required this.activity,
    required this.enter,
  });

  final int timeMs;

  /// IN_VEHICLE, ON_BICYCLE, WALKING, RUNNING or STILL.
  final String activity;
  final bool enter;
}

class RawLog {
  const RawLog({this.fixes = const [], this.activities = const []});

  final List<RawFix> fixes;
  final List<RawActivityEvent> activities;

  bool get isEmpty => fixes.isEmpty;
}

/// Parses the recorder's JSON-lines log, keeping entries at or after
/// [fromMs]. Broken lines (a write cut off by a crash) are skipped. The result
/// is sorted by time.
RawLog parseRawLogLines(Iterable<String> lines, {int fromMs = 0}) {
  final fixes = <RawFix>[];
  final activities = <RawActivityEvent>[];
  for (final line in lines) {
    if (line.isEmpty) continue;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      continue;
    }
    if (decoded is! Map) continue;
    final t = (decoded['t'] as num?)?.toInt();
    if (t == null || t < fromMs) continue;
    switch (decoded['k']) {
      case 'p':
        final lat = (decoded['la'] as num?)?.toDouble();
        final lng = (decoded['lo'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        if (lat.abs() > 90 || lng.abs() > 180) continue;
        fixes.add(
          RawFix(
            timeMs: t,
            lat: lat,
            lng: lng,
            accuracy: (decoded['ac'] as num?)?.toDouble(),
            speed: (decoded['sp'] as num?)?.toDouble(),
          ),
        );
      case 'a':
        final activity = decoded['a'];
        if (activity is! String) continue;
        activities.add(
          RawActivityEvent(
            timeMs: t,
            activity: activity,
            enter: decoded['e'] == 1,
          ),
        );
    }
  }
  fixes.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  activities.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  return RawLog(fixes: fixes, activities: activities);
}

final _logFileName = RegExp(r'^(\d{4})-(\d{2})-(\d{2})\.jsonl$');

/// Reads every daily log file in [dirPath] that can hold entries at or after
/// [fromMs]. Blocking IO: call it inside an isolate.
RawLog readRawLogDirectory(String dirPath, {int fromMs = 0}) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return const RawLog();
  final from = DateTime.fromMillisecondsSinceEpoch(fromMs);
  // A file is named by the local day of its entries; start a day early so
  // a timezone change can't skip one.
  final firstDay = DateTime(from.year, from.month, from.day - 1);
  final lines = <String>[];
  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    final match = _logFileName.firstMatch(name);
    if (match == null) continue;
    final day = DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    if (day.isBefore(firstDay)) continue;
    try {
      lines.addAll(entity.readAsLinesSync());
    } on FileSystemException {
      continue;
    }
  }
  return parseRawLogLines(lines, fromMs: fromMs);
}
