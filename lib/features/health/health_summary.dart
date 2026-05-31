import 'package:health/health.dart';
import 'package:intl/intl.dart';

import '../../core/period_range.dart';
import 'health_anomaly_filter.dart';
import 'health_service.dart';
import 'step_counter.dart';

typedef TimeInterval = ({DateTime start, DateTime end});

/// One calendar wake-day in the analysis month (safely captures overnight sleep).
class DailySleepEntry {
  const DailySleepEntry({required this.wakeDate, this.session});

  final DateTime wakeDate;
  final SleepSummary? session;

  bool get hasData => session != null;
}

/// Monthly summary optimized for AI insight payloads.
class MonthlyHealthSummary {
  const MonthlyHealthSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.avgStepsPerDay,
    required this.dailySleep,
    required this.dailySteps,
    required this.dayCount,
    this.anomalyFilter = const HealthAnomalyFilter(),
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final double avgStepsPerDay;
  final List<DailySleepEntry> dailySleep;
  final Map<DateTime, int> dailySteps;
  final int dayCount;
  final HealthAnomalyFilter anomalyFilter;

  String get periodRangeLabel => formatPeriodRange(periodStart, periodEnd);

  int get sleepNightsTracked => dailySleep.where((d) => d.hasData).length;

  factory MonthlyHealthSummary.fromFetch(MonthlyHealthFetchResult fetch) {
    final stepValues = fetch.dailySteps.values.toList();
    final days = fetch.dayCount;
    final avgSteps = stepValues.isEmpty || days == 0
        ? 0.0
        : stepValues.reduce((a, b) => a + b) / days;

    final dailySleep = _dailySleepForPeriod(
      fetch.points,
      fetch.periodStart,
      days,
    );

    return MonthlyHealthSummary(
      periodStart: fetch.periodStart,
      periodEnd: fetch.periodEnd,
      avgStepsPerDay: avgSteps,
      dailySleep: dailySleep,
      dailySteps: fetch.dailySteps,
      dayCount: days,
    );
  }

  String toSleepPromptText() {
    return dailySleep
        .where((day) => day.hasData)
        .map((day) {
          final s = day.session!;
          return '- ${formatWakeDate(day.wakeDate)}: ${formatDuration(s.duration)}, '
              'bedtime ${formatTime(s.startTime)}, wake ${formatTime(s.endTime)}';
        })
        .join('\n');
  }

  /// Full health block inserted into the monthly analysis prompt.
  /// Only includes statistically or rule-flagged sleep/step outliers.
  String toAnalysisPromptText() {
    final report = anomalyFilter.analyze(this);
    return report.toPromptText(
      periodRangeLabel: periodRangeLabel,
      sourceLabel: 'Samsung Health (via Health Connect)',
      dayCount: dayCount,
      avgStepsPerDay: avgStepsPerDay,
    );
  }
}

class SleepSummary {
  const SleepSummary({
    required this.duration,
    required this.startTime,
    required this.endTime,
  });

  final Duration duration;
  final DateTime startTime;
  final DateTime endTime;
}

List<DailySleepEntry> _dailySleepForPeriod(
  List<HealthDataPoint> data,
  DateTime periodStart,
  int dayCount,
) {
  const sleepTypes = {
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
  };

  final sleepPoints = data.where((p) => sleepTypes.contains(p.type)).toList();
  final firstDay = DateTime(
    periodStart.year,
    periodStart.month,
    periodStart.day,
  );
  final entries = <DailySleepEntry>[];

  for (var offset = 0; offset < dayCount; offset++) {
    final wakeDay = firstDay.add(Duration(days: offset));
    final session = sleepPoints.isEmpty
        ? null
        : _sleepForWakeDay(sleepPoints, wakeDay);
    entries.add(DailySleepEntry(wakeDate: wakeDay, session: session));
  }

  return entries;
}

SleepSummary? _sleepForWakeDay(
  List<HealthDataPoint> sleepPoints,
  DateTime wakeDay,
) {
  const minimumNightSleep = Duration(hours: 2);
  const maxNightSplitGap = Duration(hours: 2);
  final dayStart = DateTime(wakeDay.year, wakeDay.month, wakeDay.day);

  // Broad window to pull previous night's bedtime and morning extensions cleanly
  final searchFrom = dayStart.subtract(const Duration(hours: 14));
  final searchTo = dayStart.add(const Duration(hours: 14));

  final primeSleepStart = dayStart.add(const Duration(hours: 1));
  final primeSleepEnd = dayStart.add(const Duration(hours: 7));

  final inWindowPoints = sleepPoints.where((p) {
    return !p.dateTo.isBefore(searchFrom) && !p.dateFrom.isAfter(searchTo);
  }).toList();

  if (inWindowPoints.isEmpty) return null;

  final dayPoints = _preferSamsungPointsForDay(
    inWindowPoints,
    wakeDate: dayStart,
  );

  // --- MACRO LEVEL: DETECT VALID SLEEP WINDOWS ---
  final sessionPoints = dayPoints
      .where((p) => p.type == HealthDataType.SLEEP_SESSION)
      .toList();

  List<TimeInterval> validNightIntervals = [];

  if (sessionPoints.isNotEmpty) {
    // 1. Merge all session tracks together first to build full blocks
    final mergedSessionIntervals = _mergeIntervals(
      sessionPoints.map((s) => (start: s.dateFrom, end: s.dateTo)),
      maxNightSplitGap,
    );

    // 2. Filter blocks down at macro-level to find intervals belonging to this night
    validNightIntervals = mergedSessionIntervals.where((interval) {
      final overlapsPrimeNight =
          interval.start.isBefore(primeSleepEnd) &&
          interval.end.isAfter(primeSleepStart);

      final morningContinuationOnWakeDay =
          interval.start.year == dayStart.year &&
          interval.start.month == dayStart.month &&
          interval.start.day == dayStart.day &&
          interval.start.isBefore(dayStart.add(const Duration(hours: 12))) &&
          interval.end.isAfter(primeSleepStart);

      if (!(overlapsPrimeNight || morningContinuationOnWakeDay)) return false;

      // Ensure it isn't an isolated daytime nap
      return !_isDaytimeNapInterval(interval, dayStart);
    }).toList();
  } else {
    // Fallback: If master sessions don't exist, build intervals out of raw stage points
    final fallbackStages = dayPoints
        .where((p) => _isAsleepStage(p.type))
        .toList();
    if (fallbackStages.isEmpty) return null;

    final mergedFallbackIntervals = _mergeIntervals(
      fallbackStages.map((p) => (start: p.dateFrom, end: p.dateTo)),
      maxNightSplitGap,
    );

    validNightIntervals = mergedFallbackIntervals
        .where((i) => !_isDaytimeNapInterval(i, dayStart))
        .toList();
  }

  if (validNightIntervals.isEmpty) return null;

  // --- MICRO LEVEL: COMPUTE EXACT MATH FROM VALID WINDOWS ---
  final startTime = validNightIntervals
      .map((i) => i.start)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  final endTime = validNightIntervals
      .map((i) => i.end)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  // Sum up actual stages falling inside verified master sleep bounds
  final asleepInWindow = _sumAsleepStagesInFixedIntervals(
    dayPoints,
    validNightIntervals,
  );

  // Dynamic fallback calculation if explicit stages are missing
  final sessionDuration = _sumDurationsInFixedIntervals(
    sessionPoints.isNotEmpty
        ? sessionPoints
        : dayPoints.where((p) => _isAsleepStage(p.type)).toList(),
    validNightIntervals,
  );

  final duration = asleepInWindow > Duration.zero
      ? asleepInWindow
      : sessionDuration;

  if (duration < minimumNightSleep) return null;

  return SleepSummary(
    duration: duration,
    startTime: startTime,
    endTime: endTime,
  );
}

Duration _sumAsleepStagesInFixedIntervals(
  List<HealthDataPoint> points,
  List<TimeInterval> allowedIntervals,
) {
  return points
      .where((p) => _isAsleepStage(p.type))
      .where((p) {
        return allowedIntervals.any(
          (interval) =>
              !p.dateTo.isBefore(interval.start) &&
              !p.dateFrom.isAfter(interval.end),
        );
      })
      .fold(Duration.zero, (sum, p) => sum + p.dateTo.difference(p.dateFrom));
}

Duration _sumDurationsInFixedIntervals(
  List<HealthDataPoint> points,
  List<TimeInterval> allowedIntervals,
) {
  return points
      .where((p) {
        return allowedIntervals.any(
          (interval) =>
              !p.dateTo.isBefore(interval.start) &&
              !p.dateFrom.isAfter(interval.end),
        );
      })
      .fold(Duration.zero, (sum, p) => sum + p.dateTo.difference(p.dateFrom));
}

bool _isDaytimeNapInterval(TimeInterval interval, DateTime wakeDayStart) {
  final onWakeDay =
      interval.start.year == wakeDayStart.year &&
      interval.start.month == wakeDayStart.month &&
      interval.start.day == wakeDayStart.day;
  if (!onWakeDay) return false;

  final startsLateMorning = interval.start.hour >= 9;
  final short =
      interval.end.difference(interval.start) <
      const Duration(hours: 1, minutes: 30);
  return startsLateMorning && short;
}

bool _isAsleepStage(HealthDataType type) =>
    type == HealthDataType.SLEEP_ASLEEP ||
    type == HealthDataType.SLEEP_DEEP ||
    type == HealthDataType.SLEEP_LIGHT ||
    type == HealthDataType.SLEEP_REM;

List<HealthDataPoint> _preferSamsungPointsForDay(
  List<HealthDataPoint> points, {
  required DateTime wakeDate,
}) {
  bool belongsToWakeWindow(HealthDataPoint p) {
    final searchFrom = wakeDate.subtract(const Duration(hours: 14));
    final searchTo = wakeDate.add(const Duration(hours: 14));
    return !p.dateTo.isBefore(searchFrom) && !p.dateFrom.isAfter(searchTo);
  }

  final targetPoints = points.where(belongsToWakeWindow).toList();
  final hasSamsungSleep = targetPoints.any(
    (p) => isSamsungHealthSource(p.sourceName),
  );

  if (!hasSamsungSleep) return points;
  return points
      .where(
        (p) => !belongsToWakeWindow(p) || isSamsungHealthSource(p.sourceName),
      )
      .toList();
}

List<TimeInterval> _mergeIntervals(
  Iterable<TimeInterval> intervals,
  Duration maxGap,
) {
  final gapLimit = maxGap;
  final sorted = intervals.toList()..sort((a, b) => a.start.compareTo(b.start));
  if (sorted.isEmpty) return const [];

  final merged = <TimeInterval>[sorted.first];
  for (final interval in sorted.skip(1)) {
    final last = merged.last;
    final gap = interval.start.difference(last.end);
    if (gap > gapLimit) {
      merged.add(interval);
      continue;
    }
    final end = interval.end.isAfter(last.end) ? interval.end : last.end;
    merged[merged.length - 1] = (start: last.start, end: end);
  }
  return merged;
}

String formatWakeDate(DateTime date) =>
    DateFormat('d MMM yyyy').format(date.toLocal());

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

String formatTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
