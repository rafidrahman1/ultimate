import 'package:health/health.dart';

/// Package name fragments for Samsung Health in Health Connect [HealthDataPoint.sourceName].
const samsungHealthSourceFragments = [
  'com.sec.android.app.shealth',
  'com.samsung.android.app.shealth',
  'com.samsung.android.apps.health',
];

/// Resolves today's step count from Health Connect using several strategies and
/// returns the highest trustworthy value (aggregate under-counts Samsung mid-day).
int resolveTodaySteps({
  required int aggregatedSteps,
  required List<HealthDataPoint> stepPoints,
  required DateTime start,
  required DateTime end,
}) {
  final maxBySource = maxStepsBySource(stepPoints, start, end);
  final samsungSource = sumStepsForSources(
    stepPoints,
    start,
    end,
    samsungHealthSourceFragments,
  );

  // Do not sum all records — overlapping sources (phone + Samsung) double-count.
  final candidates = <int>[
    aggregatedSteps,
    maxBySource,
    samsungSource,
  ].where((count) => count > 0);

  if (candidates.isEmpty) return 0;
  return candidates.reduce((a, b) => a > b ? a : b);
}

int sumStepsInInterval(
  List<HealthDataPoint> data,
  DateTime start,
  DateTime end,
) {
  var total = 0.0;
  for (final point in data.where((p) => p.type == HealthDataType.STEPS)) {
    if (!point.dateFrom.isBefore(point.dateTo)) continue;
    if (point.dateTo.isBefore(start) || point.dateFrom.isAfter(end)) {
      continue;
    }
    final value = point.value;
    if (value is NumericHealthValue) {
      total += value.numericValue;
    }
  }
  return total.round();
}

int maxStepsBySource(
  List<HealthDataPoint> data,
  DateTime start,
  DateTime end,
) {
  final bySource = <String, double>{};
  for (final point in data.where((p) => p.type == HealthDataType.STEPS)) {
    if (!point.dateFrom.isBefore(point.dateTo)) continue;
    if (point.dateTo.isBefore(start) || point.dateFrom.isAfter(end)) {
      continue;
    }
    final value = point.value;
    if (value is! NumericHealthValue) continue;
    final source = point.sourceName.isEmpty ? 'unknown' : point.sourceName;
    bySource[source] = (bySource[source] ?? 0) + value.numericValue;
  }
  if (bySource.isEmpty) return 0;
  return bySource.values
      .map((v) => v.round())
      .reduce((a, b) => a > b ? a : b);
}

int sumStepsForSources(
  List<HealthDataPoint> data,
  DateTime start,
  DateTime end,
  List<String> sourceFragments,
) {
  var total = 0.0;
  for (final point in data.where((p) => p.type == HealthDataType.STEPS)) {
    if (!point.dateFrom.isBefore(point.dateTo)) continue;
    if (point.dateTo.isBefore(start) || point.dateFrom.isAfter(end)) {
      continue;
    }
    final matchesSource = sourceFragments.any(
      (fragment) => point.sourceName.contains(fragment),
    );
    if (!matchesSource) continue;

    final value = point.value;
    if (value is NumericHealthValue) {
      total += value.numericValue;
    }
  }
  return total.round();
}

bool isSamsungHealthSource(String sourceName) {
  return samsungHealthSourceFragments.any(sourceName.contains);
}
