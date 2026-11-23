import 'dart:math' as math;

import 'package:personal/features/location/data/timeline_profile.dart';
import 'package:personal/features/location/recording/raw_location_log.dart';

enum RecordedKind { visit, move }

/// A stay or a trip worked out from the raw log, before places and travel
/// modes are named.
class RecordedSegment {
  const RecordedSegment({
    required this.kind,
    required this.startMs,
    required this.endMs,
    this.center,
    this.fixCount = 0,
    this.distanceMeters = 0,
    this.p90Kmh,
    this.activity,
    this.from,
    this.to,
  });

  final RecordedKind kind;
  final int startMs;
  final int endMs;

  /// Visit: where it was.
  final GeoPoint? center;
  final int fixCount;

  /// Move: path length.
  final double distanceMeters;

  /// Move: 90th-percentile speed, km/h. Close to cruising speed, unlike the
  /// average, which red lights drag down.
  final double? p90Kmh;

  /// Move: Android's dominant activity (IN_VEHICLE, ON_BICYCLE, WALKING,
  /// RUNNING), or null when it didn't say.
  final String? activity;
  final GeoPoint? from;
  final GeoPoint? to;

  bool get isVisit => kind == RecordedKind.visit;
  DateTime get start => DateTime.fromMillisecondsSinceEpoch(startMs);
  DateTime get end => DateTime.fromMillisecondsSinceEpoch(endMs);
  Duration get duration => Duration(milliseconds: endMs - startMs);

  /// Average speed door to door, km/h.
  double get avgKmh {
    final hours = (endMs - startMs) / 3600000;
    return hours <= 0 ? 0 : distanceMeters / 1000 / hours;
  }

  Map<String, dynamic> toJson() => {
    'k': kind == RecordedKind.visit ? 'v' : 'm',
    's': startMs,
    'e': endMs,
    if (center != null) 'c': [center!.latitude, center!.longitude],
    if (fixCount > 0) 'n': fixCount,
    if (distanceMeters > 0) 'd': distanceMeters.round(),
    if (p90Kmh != null) 'p': double.parse(p90Kmh!.toStringAsFixed(1)),
    if (activity != null) 'a': activity,
    if (from != null) 'f': [from!.latitude, from!.longitude],
    if (to != null) 't': [to!.latitude, to!.longitude],
  };

  static RecordedSegment? fromJson(Map<String, dynamic> json) {
    final start = (json['s'] as num?)?.toInt();
    final end = (json['e'] as num?)?.toInt();
    if (start == null || end == null) return null;
    GeoPoint? point(Object? raw) {
      if (raw is! List || raw.length != 2) return null;
      final lat = (raw[0] as num?)?.toDouble();
      final lng = (raw[1] as num?)?.toDouble();
      return lat == null || lng == null ? null : GeoPoint(lat, lng);
    }

    return RecordedSegment(
      kind: json['k'] == 'v' ? RecordedKind.visit : RecordedKind.move,
      startMs: start,
      endMs: end,
      center: point(json['c']),
      fixCount: (json['n'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['d'] as num?)?.toDouble() ?? 0,
      p90Kmh: (json['p'] as num?)?.toDouble(),
      activity: json['a'] as String?,
      from: point(json['f']),
      to: point(json['t']),
    );
  }
}

class SegmenterConfig {
  const SegmenterConfig({
    this.stayRadiusMeters = 100,
    this.minStay = const Duration(minutes: 5),
    this.sureStay = const Duration(minutes: 20),
    this.maxAccuracyMeters = 150,
    this.maxSpeedMps = 70,
    this.minMoveMeters = 100,
    this.minPiece = const Duration(minutes: 2),
    this.maxBlindGap = const Duration(hours: 2),
  });

  /// Fixes within this of a stay's centre belong to it.
  final double stayRadiusMeters;

  /// Shorter than this in one spot is a pause, not a visit.
  final Duration minStay;

  /// At least this long in one spot is a visit even if Android thought you
  /// were in a vehicle (a jam that long is still where you were).
  final Duration sureStay;

  /// Fixes vaguer than this are ignored.
  final double maxAccuracyMeters;

  /// A jump faster than this (250 km/h) is a bad fix.
  final double maxSpeedMps;

  /// A trip shorter than this is GPS drift.
  final double minMoveMeters;

  /// Activity stretches shorter than this don't split a trip.
  final Duration minPiece;

  /// A trip with almost no fixes and a longer gap than this (phone off) is
  /// left out rather than guessed.
  final Duration maxBlindGap;
}

class _Stay {
  _Stay(this.first, this.last, this.lat, this.lng, this.count);

  int first;
  int last;
  double lat;
  double lng;
  int count;

  GeoPoint get center => GeoPoint(lat, lng);
}

class _Interval {
  _Interval(this.activity, this.startMs, this.endMs);

  final String activity;
  final int startMs;
  int endMs;
}

/// Turns raw fixes into alternating visits and moves, oldest first.
List<RecordedSegment> segmentTimeline(
  RawLog log, {
  SegmenterConfig config = const SegmenterConfig(),
}) {
  final fixes = _cleanFixes(log.fixes, config);
  if (fixes.isEmpty) return const [];
  final intervals = _activityIntervals(
    log.activities,
    endMs: fixes.last.timeMs,
  );

  final stays = _mergeStays(
    _findStays(fixes, intervals, config),
    fixes,
    config,
  );

  final segments = <RecordedSegment>[];
  void addMove(int from, int to) {
    if (to <= from) return;
    segments.addAll(_moves(fixes, from, to, intervals, config));
  }

  var cursor = 0;
  for (final stay in stays) {
    addMove(cursor, stay.first);
    segments.add(
      RecordedSegment(
        kind: RecordedKind.visit,
        startMs: fixes[stay.first].timeMs,
        endMs: fixes[stay.last].timeMs,
        center: stay.center,
        fixCount: stay.count,
      ),
    );
    cursor = stay.last;
  }
  addMove(cursor, fixes.length - 1);
  return segments;
}

List<RawFix> _cleanFixes(List<RawFix> raw, SegmenterConfig config) {
  final sorted = [
    for (final f in raw)
      if (f.accuracy == null || f.accuracy! <= config.maxAccuracyMeters) f,
  ]..sort((a, b) => a.timeMs.compareTo(b.timeMs));
  final kept = <RawFix>[];
  for (final fix in sorted) {
    if (kept.isNotEmpty) {
      final previous = kept.last;
      final dt = (fix.timeMs - previous.timeMs) / 1000;
      if (dt <= 0) continue;
      final speed = previous.point.distanceTo(fix.point) / dt;
      // A teleport within a few minutes is a bad fix; over hours it's a
      // flight or the phone being off.
      if (speed > config.maxSpeedMps && dt < 600) continue;
    }
    kept.add(fix);
  }
  return kept;
}

List<_Interval> _activityIntervals(
  List<RawActivityEvent> events, {
  required int endMs,
}) {
  final intervals = <_Interval>[];
  _Interval? open;
  for (final event in events) {
    if (event.enter) {
      if (open != null) open.endMs = event.timeMs;
      open = _Interval(event.activity, event.timeMs, event.timeMs);
      intervals.add(open);
    } else if (open != null && open.activity == event.activity) {
      open.endMs = event.timeMs;
      open = null;
    }
  }
  if (open != null) open.endMs = math.max(open.startMs, endMs);
  return intervals;
}

/// Milliseconds of each activity inside `[from, to]`.
Map<String, int> _activityOverlap(List<_Interval> intervals, int from, int to) {
  final overlap = <String, int>{};
  for (final interval in intervals) {
    final a = math.max(from, interval.startMs);
    final b = math.min(to, interval.endMs);
    if (b <= a) continue;
    overlap.update(
      interval.activity,
      (v) => v + b - a,
      ifAbsent: () => b - a,
    );
  }
  return overlap;
}

const _vehicleActivities = {'IN_VEHICLE', 'ON_BICYCLE'};

List<_Stay> _findStays(
  List<RawFix> fixes,
  List<_Interval> intervals,
  SegmenterConfig config,
) {
  final stays = <_Stay>[];
  var i = 0;
  while (i < fixes.length) {
    var lat = fixes[i].lat;
    var lng = fixes[i].lng;
    var count = 1;
    var j = i;
    while (j + 1 < fixes.length) {
      final next = fixes[j + 1];
      final radius = math.max(
        config.stayRadiusMeters,
        math.min(next.accuracy ?? 0, config.maxAccuracyMeters),
      );
      if (GeoPoint(lat, lng).distanceTo(next.point) > radius) break;
      count++;
      lat += (next.lat - lat) / count;
      lng += (next.lng - lng) / count;
      j++;
    }
    final duration = fixes[j].timeMs - fixes[i].timeMs;
    if (duration >= config.minStay.inMilliseconds &&
        _isRealStop(fixes[i].timeMs, fixes[j].timeMs, intervals, config)) {
      stays.add(_Stay(i, j, lat, lng, count));
      i = j + 1;
    } else {
      i++;
    }
  }
  return stays;
}

/// Stuck in traffic looks like a short stay; Android still says "vehicle".
bool _isRealStop(
  int from,
  int to,
  List<_Interval> intervals,
  SegmenterConfig config,
) {
  final duration = to - from;
  if (duration >= config.sureStay.inMilliseconds) return true;
  final overlap = _activityOverlap(intervals, from, to);
  final inVehicle = overlap.entries
      .where((e) => _vehicleActivities.contains(e.key))
      .fold<int>(0, (sum, e) => sum + e.value);
  return inVehicle < duration * 0.6;
}

/// Joins back-to-back stays at the same spot, split by a drifting fix.
List<_Stay> _mergeStays(
  List<_Stay> stays,
  List<RawFix> fixes,
  SegmenterConfig config,
) {
  final merged = <_Stay>[];
  for (final stay in stays) {
    if (merged.isNotEmpty) {
      final previous = merged.last;
      final near =
          previous.center.distanceTo(stay.center) <= config.stayRadiusMeters;
      final gap = fixes[stay.first].timeMs - fixes[previous.last].timeMs;
      if (near && gap <= const Duration(minutes: 15).inMilliseconds) {
        final total = previous.count + stay.count;
        previous
          ..lat =
              (previous.lat * previous.count + stay.lat * stay.count) / total
          ..lng =
              (previous.lng * previous.count + stay.lng * stay.count) / total
          ..count = total
          ..last = stay.last;
        continue;
      }
    }
    merged.add(stay);
  }
  return merged;
}

/// The trip between fix [from] and fix [to], split where Android saw the
/// activity change (walk to the bus stop, then the bus).
List<RecordedSegment> _moves(
  List<RawFix> fixes,
  int from,
  int to,
  List<_Interval> intervals,
  SegmenterConfig config,
) {
  final startMs = fixes[from].timeMs;
  final endMs = fixes[to].timeMs;
  if (endMs <= startMs) return const [];

  final pieces = _activityPieces(intervals, startMs, endMs, config);
  if (pieces.length <= 1) {
    final move = _move(fixes, from, to, startMs, endMs, intervals, config);
    return move == null ? const [] : [move];
  }

  final result = <RecordedSegment>[];
  var cursor = from;
  for (var k = 0; k < pieces.length; k++) {
    final pieceEnd = k == pieces.length - 1 ? endMs : pieces[k].endMs;
    var last = cursor;
    while (last < to && fixes[last + 1].timeMs <= pieceEnd) {
      last++;
    }
    if (k == pieces.length - 1) last = to;
    final pieceStart = k == 0 ? startMs : fixes[cursor].timeMs;
    final move = _move(
      fixes,
      cursor,
      last,
      pieceStart,
      k == pieces.length - 1 ? endMs : fixes[last].timeMs,
      intervals,
      config,
      activity: pieces[k].activity,
    );
    if (move != null) result.add(move);
    cursor = last;
  }
  return result;
}

/// Non-still activity stretches in `[startMs, endMs]`, with short blips
/// folded into their neighbours.
List<_Interval> _activityPieces(
  List<_Interval> intervals,
  int startMs,
  int endMs,
  SegmenterConfig config,
) {
  final pieces = <_Interval>[];
  for (final interval in intervals) {
    if (interval.activity == 'STILL') continue;
    final a = math.max(startMs, interval.startMs);
    final b = math.min(endMs, interval.endMs);
    if (b <= a) continue;
    if (pieces.isNotEmpty && pieces.last.activity == interval.activity) {
      pieces.last.endMs = b;
    } else {
      pieces.add(_Interval(interval.activity, a, b));
    }
  }
  pieces.removeWhere(
    (p) => p.endMs - p.startMs < config.minPiece.inMilliseconds,
  );
  // Neighbours of the same kind after a blip was dropped become one.
  final joined = <_Interval>[];
  for (final piece in pieces) {
    if (joined.isNotEmpty && joined.last.activity == piece.activity) {
      joined.last.endMs = piece.endMs;
    } else {
      joined.add(piece);
    }
  }
  return joined;
}

RecordedSegment? _move(
  List<RawFix> fixes,
  int from,
  int to,
  int startMs,
  int endMs,
  List<_Interval> intervals,
  SegmenterConfig config, {
  String? activity,
}) {
  var distance = 0.0;
  final speeds = <double>[];
  for (var k = from + 1; k <= to; k++) {
    final a = fixes[k - 1];
    final b = fixes[k];
    final d = a.point.distanceTo(b.point);
    distance += d;
    final dt = (b.timeMs - a.timeMs) / 1000;
    if (b.speed != null) {
      speeds.add(b.speed!);
    } else if (dt > 0 && dt <= 120) {
      speeds.add(d / dt);
    }
  }
  if (distance < config.minMoveMeters) return null;
  final fixCount = to - from + 1;
  if (fixCount < 4 && endMs - startMs > config.maxBlindGap.inMilliseconds) {
    return null;
  }

  speeds.sort();
  final p90 = speeds.isEmpty
      ? null
      : speeds[((speeds.length - 1) * 0.9).round()] * 3.6;

  return RecordedSegment(
    kind: RecordedKind.move,
    startMs: startMs,
    endMs: endMs,
    distanceMeters: distance,
    p90Kmh: p90,
    activity: activity ?? _dominantActivity(intervals, startMs, endMs),
    fixCount: fixCount,
    from: fixes[from].point,
    to: fixes[to].point,
  );
}

String? _dominantActivity(List<_Interval> intervals, int startMs, int endMs) {
  final overlap = _activityOverlap(intervals, startMs, endMs)..remove('STILL');
  if (overlap.isEmpty) return null;
  final best = overlap.entries.reduce((a, b) => a.value >= b.value ? a : b);
  // A few seconds of "walking" during a long trip says nothing.
  if (best.value < (endMs - startMs) * 0.2) return null;
  return best.key;
}
