import 'package:intl/intl.dart' show NumberFormat;

import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_metrics.dart';
import 'package:personal/features/health/vitals_models.dart';

/// Each side of a comparison needs at least this many days.
const minPatternDays = 4;

const _shortSleep = Duration(hours: 6);

/// A difference between two groups of days, e.g. steps after short nights vs
/// after full nights. These are observations about one person's recent data,
/// not causes.
class HealthPattern {
  const HealthPattern({
    required this.id,
    required this.title,
    required this.labelA,
    required this.labelB,
    required this.valueA,
    required this.valueB,
    required this.daysA,
    required this.daysB,
    required this.unit,
    required this.strength,
  });

  final String id;
  final String title;
  final String labelA;
  final String labelB;
  final double valueA;
  final double valueB;
  final int daysA;
  final int daysB;

  /// What the values count: `steps`, `bpm`, `ms`, `min`.
  final String unit;

  /// Relative size of the difference, for ordering.
  final double strength;

  String format(double value) => switch (unit) {
    'steps' => '${NumberFormat.decimalPattern().format(value.round())} steps',
    'min' => '${value.round()} min',
    _ => '${value.round()} $unit',
  };

  /// `Steps: 6,200 steps after a night under 6 h (5 days) vs 8,100 steps after 7 h or more (9 days)`.
  String get sentence =>
      '$title: ${format(valueA)} $labelA ($daysA days) vs '
      '${format(valueB)} $labelB ($daysB days)';
}

double _mean(Iterable<double> values) =>
    values.fold<double>(0, (sum, v) => sum + v) / values.length;

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Finds the comparisons with enough data and a large enough difference.
List<HealthPattern> computeHealthPatterns(
  List<DailySleepEntry> nights,
  VitalsSummary? vitals,
) {
  if (vitals == null) return const [];

  final byDay = {for (final d in vitals.days) d.date: d};
  final sleepByWake = {
    for (final n in nights)
      if (n.hasData) _day(n.wakeDate): n.session!,
  };

  final patterns = <HealthPattern>[];

  /// Compares [value] on days following a short night against a full one.
  void afterSleep({
    required String id,
    required String title,
    required double? Function(DailyVitals) value,
    required String unit,
    required double minAbsolute,
    required double minRelative,
  }) {
    final shortDays = <double>[];
    final fullDays = <double>[];
    sleepByWake.forEach((wakeDay, session) {
      final v = byDay[wakeDay];
      final x = v == null ? null : value(v);
      if (x == null) return;
      if (session.duration < _shortSleep) {
        shortDays.add(x);
      } else if (session.duration >= sleepTargetDuration) {
        fullDays.add(x);
      }
    });
    _add(
      patterns,
      id: id,
      title: title,
      labelA: 'after a night under 6 h',
      labelB: 'after 7 h or more',
      a: shortDays,
      b: fullDays,
      unit: unit,
      minAbsolute: minAbsolute,
      minRelative: minRelative,
    );
  }

  afterSleep(
    id: 'steps_after_sleep',
    title: 'Steps',
    value: (d) => d.steps?.toDouble(),
    unit: 'steps',
    minAbsolute: 500,
    minRelative: 0.08,
  );
  afterSleep(
    id: 'rhr_after_sleep',
    title: 'Resting heart rate',
    value: (d) => d.restingHr?.toDouble(),
    unit: 'bpm',
    minAbsolute: 2,
    minRelative: 0,
  );
  afterSleep(
    id: 'hrv_after_sleep',
    title: 'Heart rate variability',
    value: (d) => d.hrvMs,
    unit: 'ms',
    minAbsolute: 4,
    minRelative: 0.08,
  );

  // Sleep the night after a workout day vs after a rest day.
  final workoutDays = {for (final w in vitals.workouts) _day(w.start)};
  final trackedDays = {
    for (final d in vitals.days)
      if (d.hasAny || workoutDays.contains(d.date)) d.date,
  };
  final afterWorkout = <double>[];
  final afterRest = <double>[];
  for (final day in trackedDays) {
    final session = sleepByWake[day.add(const Duration(days: 1))];
    if (session == null) continue;
    final minutes = session.duration.inMinutes.toDouble();
    (workoutDays.contains(day) ? afterWorkout : afterRest).add(minutes);
  }
  _add(
    patterns,
    id: 'sleep_after_workout',
    title: 'Sleep',
    labelA: 'the night after a workout',
    labelB: 'after a day without one',
    a: afterWorkout,
    b: afterRest,
    unit: 'min',
    minAbsolute: 15,
    minRelative: 0,
  );

  // Sleep after active days vs quiet ones (split at the median).
  final stepDays = vitals.stepDays;
  if (stepDays.length >= minPatternDays * 2) {
    final sorted = [for (final d in stepDays) d.steps!]..sort();
    final median = sorted[sorted.length ~/ 2];
    final active = <double>[];
    final quiet = <double>[];
    for (final d in stepDays) {
      final session = sleepByWake[d.date.add(const Duration(days: 1))];
      if (session == null) continue;
      final minutes = session.duration.inMinutes.toDouble();
      (d.steps! >= median ? active : quiet).add(minutes);
    }
    _add(
      patterns,
      id: 'sleep_after_steps',
      title: 'Sleep',
      labelA: 'after more active days',
      labelB: 'after quieter days',
      a: active,
      b: quiet,
      unit: 'min',
      minAbsolute: 15,
      minRelative: 0,
    );
  }

  patterns.sort((a, b) => b.strength.compareTo(a.strength));
  return patterns;
}

void _add(
  List<HealthPattern> into, {
  required String id,
  required String title,
  required String labelA,
  required String labelB,
  required List<double> a,
  required List<double> b,
  required String unit,
  required double minAbsolute,
  required double minRelative,
}) {
  if (a.length < minPatternDays || b.length < minPatternDays) return;
  final meanA = _mean(a);
  final meanB = _mean(b);
  final diff = (meanA - meanB).abs();
  final base = meanB == 0 ? 1.0 : meanB.abs();
  if (diff < minAbsolute || diff / base < minRelative) return;
  into.add(
    HealthPattern(
      id: id,
      title: title,
      labelA: labelA,
      labelB: labelB,
      valueA: meanA,
      valueB: meanB,
      daysA: a.length,
      daysB: b.length,
      unit: unit,
      strength: diff / base,
    ),
  );
}
