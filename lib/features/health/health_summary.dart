import 'package:health/health.dart';
import 'package:intl/intl.dart';

import '../../core/period_range.dart';
import 'health_service.dart';
import 'step_counter.dart';

typedef TimeInterval = ({DateTime start, DateTime end});

/// One calendar wake-day in the 7-day window (may have no sleep data).
class DailySleepEntry {
  const DailySleepEntry({required this.wakeDate, this.session});

  final DateTime wakeDate;
  final SleepSummary? session;

  bool get hasData => session != null;
}

/// Weekly summary for AI prompts (7-day window).
class WeeklyHealthSummary {
  const WeeklyHealthSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.avgStepsPerDay,
    required this.dailySleep,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final double avgStepsPerDay;
  final List<DailySleepEntry> dailySleep;

  String get periodRangeLabel => formatPeriodRange(periodStart, periodEnd);

  int get sleepNightsTracked => dailySleep.where((d) => d.hasData).length;

  static const weeklyDayCount = 7;

  factory WeeklyHealthSummary.fromWeeklyFetch(WeeklyHealthFetchResult fetch) {
    final stepValues = fetch.dailySteps.values.toList();
    final avgSteps = stepValues.isEmpty
        ? 0.0
        : stepValues.reduce((a, b) => a + b) / weeklyDayCount;

    final dailySleep = _dailySleepForWeek(fetch.points, fetch.periodStart);

    return WeeklyHealthSummary(
      periodStart: fetch.periodStart,
      periodEnd: fetch.periodEnd,
      avgStepsPerDay: avgSteps,
      dailySleep: dailySleep,
    );
  }

  String toSleepPromptText() {
    if (sleepNightsTracked == 0) return 'No sleep records in period';
    return dailySleep
        .map((day) {
          if (!day.hasData) {
            return '- ${formatWakeDate(day.wakeDate)}: no data';
          }
          final s = day.session!;
          return '- ${formatWakeDate(day.wakeDate)}: ${formatDuration(s.duration)}, '
              'bedtime ${formatTime(s.startTime)}, wake ${formatTime(s.endTime)}';
        })
        .join('\n');
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

  static SleepSummary? fromData(List<HealthDataPoint> data) {
    const sleepTypes = {
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_AWAKE,
    };

    final sleepPoints =
        data.where((p) => sleepTypes.contains(p.type)).toList();
    if (sleepPoints.isEmpty) return null;

    sleepPoints.sort((a, b) => b.dateTo.compareTo(a.dateTo));

    final latestPoint = sleepPoints.first;
    final sessionThreshold =
        latestPoint.dateTo.subtract(const Duration(hours: 14));

    final sessionPoints = sleepPoints
        .where((p) => p.dateTo.isAfter(sessionThreshold))
        .toList();

    var totalAsleep = Duration.zero;
    var sessionStart = latestPoint.dateFrom;
    var sessionEnd = latestPoint.dateTo;

    final stages = sessionPoints
        .where(
          (p) => {
            HealthDataType.SLEEP_ASLEEP,
            HealthDataType.SLEEP_DEEP,
            HealthDataType.SLEEP_LIGHT,
            HealthDataType.SLEEP_REM,
          }.contains(p.type),
        )
        .toList();

    if (stages.isNotEmpty) {
      for (final stage in stages) {
        totalAsleep += stage.dateTo.difference(stage.dateFrom);
      }
      for (final point in sessionPoints) {
        if (point.dateFrom.isBefore(sessionStart)) {
          sessionStart = point.dateFrom;
        }
        if (point.dateTo.isAfter(sessionEnd)) sessionEnd = point.dateTo;
      }
    } else {
      final sessions = sessionPoints
          .where((p) => p.type == HealthDataType.SLEEP_SESSION)
          .toList();
      if (sessions.isNotEmpty) {
        final latestSession = sessions.first;
        totalAsleep =
            latestSession.dateTo.difference(latestSession.dateFrom);
        sessionStart = latestSession.dateFrom;
        sessionEnd = latestSession.dateTo;
      } else {
        totalAsleep = latestPoint.dateTo.difference(latestPoint.dateFrom);
        sessionStart = latestPoint.dateFrom;
        sessionEnd = latestPoint.dateTo;
      }
    }

    return SleepSummary(
      duration: totalAsleep,
      startTime: sessionStart,
      endTime: sessionEnd,
    );
  }
}

List<DailySleepEntry> _dailySleepForWeek(
  List<HealthDataPoint> data,
  DateTime periodStart,
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

  for (var offset = 0; offset < WeeklyHealthSummary.weeklyDayCount; offset++) {
    final wakeDay = firstDay.add(Duration(days: offset));
    final session =
        sleepPoints.isEmpty ? null : _sleepForWakeDay(sleepPoints, wakeDay);
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
  final searchFrom = dayStart.subtract(const Duration(hours: 18));
  final searchTo = dayStart.add(const Duration(hours: 14));

  final inWindow = sleepPoints
      .where(
        (p) =>
            !p.dateTo.isBefore(searchFrom) && !p.dateFrom.isAfter(searchTo),
      )
      .toList();
  if (inWindow.isEmpty) return null;
  final dayPoints = _preferSamsungPointsForDay(inWindow, wakeDate: dayStart);

  final wakeDate = dayStart;
  final sessionEnds = dayPoints
      .where((p) => p.type == HealthDataType.SLEEP_SESSION)
      .where((p) {
        final endDay = DateTime(
          p.dateTo.year,
          p.dateTo.month,
          p.dateTo.day,
        );
        return endDay == wakeDate;
      })
      .toList();

  if (sessionEnds.isNotEmpty) {
    final mergedSessionIntervals = _mergeIntervals(
      sessionEnds.map((s) => (start: s.dateFrom, end: s.dateTo)),
      maxNightSplitGap,
    );
    if (mergedSessionIntervals.isEmpty) return null;

    mergedSessionIntervals.sort(
      (a, b) => b.end.difference(b.start).compareTo(a.end.difference(a.start)),
    );
    final primaryInterval = mergedSessionIntervals.first;
    final sessionDuration = primaryInterval.end.difference(primaryInterval.start);
    if (sessionDuration < minimumNightSleep) return null;

    final sessionFrom = primaryInterval.start.subtract(const Duration(hours: 1));
    final sessionTo = primaryInterval.end.add(const Duration(hours: 1));
    final sessionPoints = dayPoints
        .where(
          (p) =>
              !p.dateTo.isBefore(sessionFrom) &&
              !p.dateFrom.isAfter(sessionTo),
        )
        .toList();

    return SleepSummary(
      duration: sessionDuration,
      startTime: primaryInterval.start,
      endTime: primaryInterval.end,
    );
  }

  final fallbackStages = dayPoints.where((p) {
    if (!_isAsleepStage(p.type)) return false;
    final endDay = DateTime(
      p.dateTo.year,
      p.dateTo.month,
      p.dateTo.day,
    );
    return endDay == wakeDate;
  }).toList();
  if (fallbackStages.isEmpty) return null;

  final mergedFallbackIntervals = _mergeIntervals(
    fallbackStages.map((p) => (start: p.dateFrom, end: p.dateTo)),
    maxNightSplitGap,
  );
  if (mergedFallbackIntervals.isEmpty) return null;

  mergedFallbackIntervals.sort(
    (a, b) => b.end.difference(b.start).compareTo(a.end.difference(a.start)),
  );
  final primaryFallback = mergedFallbackIntervals.first;
  final fallbackDuration = primaryFallback.end.difference(primaryFallback.start);
  if (fallbackDuration < minimumNightSleep) return null;

  return SleepSummary(
    duration: fallbackDuration,
    startTime: primaryFallback.start,
    endTime: primaryFallback.end,
  );
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
  bool endsOnWakeDate(HealthDataPoint p) =>
      p.dateTo.year == wakeDate.year &&
      p.dateTo.month == wakeDate.month &&
      p.dateTo.day == wakeDate.day;

  final wakeDatePoints = points.where(endsOnWakeDate).toList();
  final hasSamsungSleep = wakeDatePoints.any(
    (p) => isSamsungHealthSource(p.sourceName),
  );
  if (!hasSamsungSleep) return points;
  return points
      .where((p) => !endsOnWakeDate(p) || isSamsungHealthSource(p.sourceName))
      .toList();
}

List<TimeInterval> _mergeIntervals(
  Iterable<TimeInterval> intervals,
  Duration maxGap,
) {
  final gapLimit = maxGap;
  final sorted = intervals.toList()
    ..sort((a, b) => a.start.compareTo(b.start));
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
