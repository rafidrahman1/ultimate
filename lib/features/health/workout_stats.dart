import 'package:health/health.dart';

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
    final inPeriod = points.where((point) {
      if (point.type != HealthDataType.WORKOUT) return false;
      final from = point.dateFrom.toLocal();
      final to = point.dateTo.toLocal();
      return from.isBefore(periodEnd) && to.isAfter(periodStart);
    }).toList()
      ..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

    if (inPeriod.isEmpty) return MonthlyWorkoutStats.empty;

    final sessions = _combineSameDayWorkouts(
      inPeriod.map(WorkoutSessionSummary.fromPoint).toList(),
    );
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

List<WorkoutSessionSummary> _combineSameDayWorkouts(
  List<WorkoutSessionSummary> sessions,
) {
  final byDay = <DateTime, List<WorkoutSessionSummary>>{};
  for (final session in sessions) {
    final day = DateTime(session.start.year, session.start.month, session.start.day);
    byDay.putIfAbsent(day, () => []).add(session);
  }

  final combined = <WorkoutSessionSummary>[];
  for (final daySessions in byDay.values) {
    if (daySessions.length < 2) {
      combined.add(daySessions.single);
      continue;
    }

    daySessions.sort((a, b) => a.start.compareTo(b.start));
    final labels = daySessions.map((s) => s.activityLabel).toSet().toList();
    final totalDistance = daySessions
        .map((s) => s.distanceKm)
        .whereType<double>()
        .fold<double>(0, (sum, km) => sum + km);

    combined.add(
      WorkoutSessionSummary(
        start: daySessions.first.start,
        end: daySessions
            .map((s) => s.end)
            .reduce((a, b) => a.isAfter(b) ? a : b),
        duration: daySessions.fold<Duration>(
          Duration.zero,
          (sum, s) => sum + s.duration,
        ),
        activityLabel: labels.length == 1 ? labels.single : labels.join(' + '),
        distanceKm: totalDistance > 0 ? totalDistance : null,
      ),
    );
  }

  combined.sort((a, b) => b.start.compareTo(a.start));
  return combined;
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
