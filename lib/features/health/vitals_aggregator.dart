import 'package:health/health.dart';

import 'package:personal/features/health/vitals_models.dart';

/// Health Connect types read for each [VitalsMetric]. Steps are not here:
/// they come from the platform's de-duplicated daily total instead.
const vitalsTypesByMetric = <VitalsMetric, HealthDataType>{
  VitalsMetric.heartRate: HealthDataType.HEART_RATE,
  VitalsMetric.restingHeartRate: HealthDataType.RESTING_HEART_RATE,
  VitalsMetric.hrv: HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
  VitalsMetric.workouts: HealthDataType.WORKOUT,
  VitalsMetric.activeEnergy: HealthDataType.ACTIVE_ENERGY_BURNED,
  VitalsMetric.distance: HealthDataType.DISTANCE_DELTA,
  VitalsMetric.weight: HealthDataType.WEIGHT,
  VitalsMetric.oxygen: HealthDataType.BLOOD_OXYGEN,
};

VitalsMetric? vitalsMetricFor(HealthDataType type) {
  for (final entry in vitalsTypesByMetric.entries) {
    if (entry.value == type) return entry.key;
  }
  return null;
}

DateTime _day(DateTime t) {
  final local = t.toLocal();
  return DateTime(local.year, local.month, local.day);
}

double? _number(HealthDataPoint point) {
  final value = point.value;
  return value is NumericHealthValue ? value.numericValue.toDouble() : null;
}

// Readings outside these ranges are sensor glitches, not physiology.
bool _plausibleHr(double v) => v >= 25 && v <= 230;
bool _plausibleWeight(double kg) => kg >= 20 && kg <= 400;

/// Builds the period summary from raw points.
///
/// [stepsByDay] is keyed by local midnight. [points] may mix any of the types
/// in [vitalsTypesByMetric]. Weight points from before the period are fine:
/// the latest one is kept as the baseline.
VitalsSummary buildVitalsSummary({
  required DateTime periodStart,
  required DateTime periodEnd,
  required int dayCount,
  required Map<DateTime, int> stepsByDay,
  required List<HealthDataPoint> points,
  required Set<VitalsMetric> readMetrics,
}) {
  final firstDay = _day(periodStart);
  final lastDay = firstDay.add(Duration(days: dayCount - 1));
  bool inPeriod(DateTime day) =>
      !day.isBefore(firstDay) && !day.isAfter(lastDay);

  final hr = <DateTime, List<double>>{};
  final resting = <DateTime, List<double>>{};
  final hrv = <DateTime, List<double>>{};
  final oxygen = <DateTime, List<double>>{};
  // day → source → total, so additive metrics use one source per day.
  final energy = <DateTime, Map<String, double>>{};
  final distance = <DateTime, Map<String, double>>{};
  final weights = <WeightReading>[];
  final workouts = <WorkoutRecord>[];
  final seenWorkouts = <String>{};
  final sources = <VitalsMetric, Set<String>>{};

  void note(HealthDataType type, HealthDataPoint p) {
    final metric = vitalsMetricFor(type);
    if (metric == null) return;
    final name = p.sourceName.isNotEmpty ? p.sourceName : p.sourceId;
    if (name.isNotEmpty) sources.putIfAbsent(metric, () => {}).add(name);
  }

  for (final p in points) {
    note(p.type, p);
    final day = _day(p.dateFrom);

    switch (p.type) {
      case HealthDataType.HEART_RATE:
        final v = _number(p);
        if (v != null && _plausibleHr(v) && inPeriod(day)) {
          hr.putIfAbsent(day, () => []).add(v);
        }
      case HealthDataType.RESTING_HEART_RATE:
        final v = _number(p);
        if (v != null && _plausibleHr(v) && inPeriod(day)) {
          resting.putIfAbsent(day, () => []).add(v);
        }
      case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
        final v = _number(p);
        if (v != null && v > 0 && v < 400 && inPeriod(day)) {
          hrv.putIfAbsent(day, () => []).add(v);
        }
      case HealthDataType.BLOOD_OXYGEN:
        var v = _number(p);
        if (v == null) break;
        // Some sources report a 0–1 fraction.
        if (v <= 1.0) v *= 100;
        if (v >= 50 && v <= 100 && inPeriod(day)) {
          oxygen.putIfAbsent(day, () => []).add(v);
        }
      case HealthDataType.ACTIVE_ENERGY_BURNED:
        final v = _number(p);
        if (v != null && v > 0 && inPeriod(day)) {
          final bySource = energy.putIfAbsent(day, () => {});
          bySource[p.sourceId] = (bySource[p.sourceId] ?? 0) + v;
        }
      case HealthDataType.DISTANCE_DELTA:
        final v = _number(p);
        if (v != null && v > 0 && inPeriod(day)) {
          final bySource = distance.putIfAbsent(day, () => {});
          bySource[p.sourceId] = (bySource[p.sourceId] ?? 0) + v;
        }
      case HealthDataType.WEIGHT:
        final v = _number(p);
        if (v != null && _plausibleWeight(v)) {
          weights.add(WeightReading(time: p.dateFrom.toLocal(), kg: v));
        }
      case HealthDataType.WORKOUT:
        final workout = _workoutFrom(p);
        if (workout == null || !inPeriod(_day(workout.start))) break;
        // The same session is often written by more than one app.
        final key =
            '${workout.type}|${workout.start.millisecondsSinceEpoch ~/ 60000}';
        if (seenWorkouts.add(key)) workouts.add(workout);
      default:
        break;
    }
  }

  double? bestSource(Map<String, double>? bySource) {
    if (bySource == null || bySource.isEmpty) return null;
    return bySource.values.reduce((a, b) => a > b ? a : b);
  }

  double mean(List<double> values) =>
      values.fold<double>(0, (sum, v) => sum + v) / values.length;

  final days = <DailyVitals>[];
  for (var i = 0; i < dayCount; i++) {
    final day = firstDay.add(Duration(days: i));
    final heart = hr[day];
    final rest = resting[day];
    final variability = hrv[day];
    final sat = oxygen[day];
    days.add(
      DailyVitals(
        date: day,
        steps: stepsByDay[day],
        activeKcal: bestSource(energy[day]),
        distanceMeters: bestSource(distance[day]),
        restingHr: rest == null ? null : mean(rest).round(),
        minHr: heart == null
            ? null
            : heart.reduce((a, b) => a < b ? a : b).round(),
        avgHr: heart == null ? null : mean(heart).round(),
        maxHr: heart == null
            ? null
            : heart.reduce((a, b) => a > b ? a : b).round(),
        hrvMs: variability == null ? null : mean(variability),
        spo2Avg: sat == null ? null : mean(sat),
        spo2Min: sat == null ? null : sat.reduce((a, b) => a < b ? a : b),
      ),
    );
  }

  workouts.sort((a, b) => a.start.compareTo(b.start));
  weights.sort((a, b) => a.time.compareTo(b.time));
  // Keep the period's readings plus the latest one before it (the baseline).
  final before = weights.where((w) => w.time.isBefore(firstDay)).toList();
  final within = weights.where((w) => !w.time.isBefore(firstDay)).toList();
  final keptWeights = [if (before.isNotEmpty) before.last, ...within];

  return VitalsSummary(
    periodStart: periodStart,
    periodEnd: periodEnd,
    days: days,
    workouts: workouts,
    weights: keptWeights,
    readMetrics: readMetrics,
    sources: sources,
  );
}

WorkoutRecord? _workoutFrom(HealthDataPoint p) {
  final value = p.value;
  if (value is! WorkoutHealthValue) return null;
  if (!p.dateTo.isAfter(p.dateFrom)) return null;

  double? meters(int? raw, HealthDataUnit? unit) {
    if (raw == null || raw <= 0) return null;
    return switch (unit) {
      HealthDataUnit.MILE => raw * 1609.344,
      HealthDataUnit.YARD => raw * 0.9144,
      HealthDataUnit.CENTIMETER => raw / 100.0,
      HealthDataUnit.INCH => raw * 0.0254,
      _ => raw.toDouble(),
    };
  }

  final kcal = value.totalEnergyBurned;
  return WorkoutRecord(
    type: value.workoutActivityType.name,
    start: p.dateFrom.toLocal(),
    end: p.dateTo.toLocal(),
    kcal: kcal == null || kcal <= 0 ? null : kcal.toDouble(),
    distanceMeters: meters(value.totalDistance, value.totalDistanceUnit),
    steps: (value.totalSteps ?? 0) > 0 ? value.totalSteps : null,
  );
}
