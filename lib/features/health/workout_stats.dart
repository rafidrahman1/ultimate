import 'package:health/health.dart';

import 'package:personal/features/health/step_counter.dart';

/// Aggregated workout metrics for one analysis month.
class MonthlyWorkoutStats {
  const MonthlyWorkoutStats({
    required this.sessionCount,
    required this.totalDistanceKm,
    required this.totalDuration,
    required this.sessions,
  });

  final int sessionCount;
  final double totalDistanceKm;
  final Duration totalDuration;
  final List<WorkoutSessionSummary> sessions;

  static const empty = MonthlyWorkoutStats(
    sessionCount: 0,
    totalDistanceKm: 0,
    totalDuration: Duration.zero,
    sessions: [],
  );

  bool get hasData => sessionCount > 0;

  factory MonthlyWorkoutStats.fromPoints(
    List<HealthDataPoint> points, {
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final inPeriod = dedupeWorkoutPoints(points).where((point) {
      final from = point.dateFrom.toLocal();
      final to = point.dateTo.toLocal();
      return from.isBefore(periodEnd) && to.isAfter(periodStart);
    }).toList()
      ..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

    if (inPeriod.isEmpty) return MonthlyWorkoutStats.empty;

    final sessions = inPeriod.map(WorkoutSessionSummary.fromPoint).toList();
    return MonthlyWorkoutStats(
      sessionCount: sessions.length,
      totalDistanceKm: sessions
          .map((s) => s.distanceKm ?? 0)
          .fold<double>(0, (sum, km) => sum + km),
      totalDuration: sessions.fold<Duration>(
        Duration.zero,
        (sum, s) => sum + s.duration,
      ),
      sessions: sessions,
    );
  }
}

class WorkoutSessionSummary {
  const WorkoutSessionSummary({
    required this.start,
    required this.end,
    required this.duration,
    required this.activityLabel,
    this.distanceKm,
  });

  final DateTime start;
  final DateTime end;
  final Duration duration;
  final String activityLabel;
  final double? distanceKm;

  factory WorkoutSessionSummary.fromPoint(HealthDataPoint point) {
    final value = point.value;
    final activityLabel = value is WorkoutHealthValue
        ? formatWorkoutActivityType(value.workoutActivityType)
        : 'Workout';

    return WorkoutSessionSummary(
      start: point.dateFrom.toLocal(),
      end: point.dateTo.toLocal(),
      duration: point.dateTo.difference(point.dateFrom),
      activityLabel: activityLabel,
      distanceKm: value is WorkoutHealthValue
          ? _distanceKmFromWorkoutValue(value)
          : null,
    );
  }
}

/// Removes duplicate workout sessions mirrored across Health Connect sources.
List<HealthDataPoint> dedupeWorkoutPoints(List<HealthDataPoint> points) {
  final workouts =
      points.where((p) => p.type == HealthDataType.WORKOUT).toList();
  if (workouts.length <= 1) return workouts;

  final samsungWorkouts =
      workouts.where((p) => isSamsungHealthSource(p.sourceName)).toList();
  final candidates = samsungWorkouts.isNotEmpty ? samsungWorkouts : workouts;

  candidates.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));

  final kept = <HealthDataPoint>[];
  for (final candidate in candidates) {
    final duplicate =
        kept.any((existing) => workoutsRepresentSameSession(existing, candidate));
    if (!duplicate) kept.add(candidate);
  }
  return kept;
}

bool workoutsRepresentSameSession(HealthDataPoint a, HealthDataPoint b) {
  if (_workoutOverlapRatio(a, b) >= 0.5) return true;

  final aDay = DateTime(a.dateFrom.year, a.dateFrom.month, a.dateFrom.day);
  final bDay = DateTime(b.dateFrom.year, b.dateFrom.month, b.dateFrom.day);
  if (aDay != bDay) return false;

  final startDiffMinutes = a.dateFrom.difference(b.dateFrom).inMinutes.abs();
  if (startDiffMinutes > 45) return false;

  return _workoutActivityMatches(a, b);
}

double _workoutOverlapRatio(HealthDataPoint a, HealthDataPoint b) {
  final overlapStart =
      a.dateFrom.isAfter(b.dateFrom) ? a.dateFrom : b.dateFrom;
  final overlapEnd = a.dateTo.isBefore(b.dateTo) ? a.dateTo : b.dateTo;
  if (!overlapEnd.isAfter(overlapStart)) return 0;

  final overlap = overlapEnd.difference(overlapStart);
  final aDuration = a.dateTo.difference(a.dateFrom);
  final bDuration = b.dateTo.difference(b.dateFrom);
  final shorter = aDuration < bDuration ? aDuration : bDuration;
  if (shorter <= Duration.zero) return 0;
  return overlap.inMicroseconds / shorter.inMicroseconds;
}

bool _workoutActivityMatches(HealthDataPoint a, HealthDataPoint b) {
  final aValue = a.value;
  final bValue = b.value;
  if (aValue is! WorkoutHealthValue || bValue is! WorkoutHealthValue) {
    return true;
  }
  return aValue.workoutActivityType == bValue.workoutActivityType;
}

double? _distanceKmFromWorkoutValue(WorkoutHealthValue value) {
  final distance = value.totalDistance;
  if (distance == null) return null;

  final meters = distance.toDouble();
  final unit = value.totalDistanceUnit ?? HealthDataUnit.METER;
  return switch (unit) {
    HealthDataUnit.METER => meters / 1000,
    HealthDataUnit.MILE => meters * 1.60934,
    HealthDataUnit.FOOT => meters * 0.0003048,
    HealthDataUnit.YARD => meters * 0.0009144,
    _ => null,
  };
}

String formatWorkoutActivityType(HealthWorkoutActivityType type) {
  final name = type.name.toLowerCase();
  return name
      .split('_')
      .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
