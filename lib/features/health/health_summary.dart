import 'package:health/health.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/period_range.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/sleep_prompt_builder.dart';
typedef TimeInterval = ({DateTime start, DateTime end});

const _samsungHealthSourceFragments = [
  'com.sec.android.app.shealth',
  'com.samsung.android.app.shealth',
  'com.samsung.android.apps.health',
];

bool isSamsungHealthSource(String sourceName) {
  final lower = sourceName.toLowerCase();
  for (final fragment in _samsungHealthSourceFragments) {
    if (lower.contains(fragment)) return true;
  }
  return false;
}

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
    required this.dailySleep,
    required this.dayCount,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final List<DailySleepEntry> dailySleep;
  final int dayCount;

  String get periodRangeLabel => formatPeriodRange(periodStart, periodEnd);

  int get sleepNightsTracked => dailySleep.where((d) => d.hasData).length;

  factory MonthlyHealthSummary.fromFetch(MonthlyHealthFetchResult fetch) {
    final dailySleep = _dailySleepForPeriod(
      fetch.points,
      fetch.periodStart,
      fetch.dayCount,
    );
    return MonthlyHealthSummary(
      periodStart: fetch.periodStart,
      periodEnd: fetch.periodEnd,
      dailySleep: dailySleep,
      dayCount: fetch.dayCount,
    );
  }

  int get sleepNightsMissing => dayCount - sleepNightsTracked;

  String toSleepPromptText({
    List<DailySleepEntry>? previousNights,
    bool includeDailyRecords = false,
  }) =>
      buildSleepPromptText(
        this,
        previousNights: previousNights,
        includeDailyRecords: includeDailyRecords,
      );

  /// Full health block inserted into the monthly analysis prompt.
  String toAnalysisPromptText({
    List<DailySleepEntry>? previousNights,
    bool includeDailyRecords = false,
  }) =>
      toSleepPromptText(
        previousNights: previousNights,
        includeDailyRecords: includeDailyRecords,
      );
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

  final searchFrom = dayStart.subtract(const Duration(hours: 18));
  final searchTo = dayStart.add(const Duration(hours: 14));

  final primeSleepStart = dayStart;
  final primeSleepEnd = dayStart.add(const Duration(hours: 10));

  final inWindowPoints = sleepPoints.where((p) {
    final from = p.dateFrom.toLocal();
    final to = p.dateTo.toLocal();
    return !to.isBefore(searchFrom) && !from.isAfter(searchTo);
  }).toList();

  if (inWindowPoints.isEmpty) return null;

  final dayPoints = _preferSamsungPointsForDay(
    inWindowPoints,
    wakeDate: dayStart,
  );

  final sessionPoints = dayPoints
      .where((p) => p.type == HealthDataType.SLEEP_SESSION)
      .toList();

  List<TimeInterval> validNightIntervals = [];

  if (sessionPoints.isNotEmpty) {
    final mergedSessionIntervals = _mergeIntervals(
      sessionPoints.map(
        (s) => (start: s.dateFrom.toLocal(), end: s.dateTo.toLocal()),
      ),
      maxNightSplitGap,
    );

    validNightIntervals = mergedSessionIntervals.where((interval) {
      return _sessionBelongsToWakeDay(
        interval,
        dayStart: dayStart,
        primeSleepStart: primeSleepStart,
        primeSleepEnd: primeSleepEnd,
      );
    }).toList();

    if (validNightIntervals.isEmpty) {
      validNightIntervals = mergedSessionIntervals
          .where(
            (interval) =>
                _sessionEndsOnWakeDay(interval, dayStart) &&
                !_isDaytimeNapInterval(interval, dayStart),
          )
          .toList();
    }
  } else {
    final fallbackStages = dayPoints
        .where((p) => _isAsleepStage(p.type))
        .toList();
    if (fallbackStages.isEmpty) return null;

    final mergedFallbackIntervals = _mergeIntervals(
      fallbackStages.map(
        (p) => (start: p.dateFrom.toLocal(), end: p.dateTo.toLocal()),
      ),
      maxNightSplitGap,
    );

    validNightIntervals = mergedFallbackIntervals
        .where(
          (interval) =>
              _sessionEndsOnWakeDay(interval, dayStart) &&
              !_isDaytimeNapInterval(interval, dayStart),
        )
        .toList();
  }

  if (validNightIntervals.isEmpty) return null;

  final startTime = validNightIntervals
      .map((i) => i.start)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  final endTime = validNightIntervals
      .map((i) => i.end)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  final asleepInWindow = _sumAsleepStagesInFixedIntervals(
    dayPoints,
    validNightIntervals,
  );

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

bool _sessionBelongsToWakeDay(
  TimeInterval interval, {
  required DateTime dayStart,
  required DateTime primeSleepStart,
  required DateTime primeSleepEnd,
}) {
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

  return !_isDaytimeNapInterval(interval, dayStart);
}

bool _sessionEndsOnWakeDay(TimeInterval interval, DateTime dayStart) {
  final end = interval.end;
  if (end.year != dayStart.year ||
      end.month != dayStart.month ||
      end.day != dayStart.day) {
    return false;
  }
  final wakeTime = end.difference(dayStart);
  return wakeTime >= const Duration(hours: 4) &&
      wakeTime <= const Duration(hours: 14);
}

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
  final hasSamsungNightSleep = targetPoints.any(_isUsableSamsungNightSleep);

  if (!hasSamsungNightSleep) return points;
  return targetPoints
      .where((p) => isSamsungHealthSource(p.sourceName))
      .toList();
}

bool _isUsableSamsungNightSleep(HealthDataPoint point) {
  if (!isSamsungHealthSource(point.sourceName)) return false;
  if (point.type == HealthDataType.SLEEP_SESSION) return true;
  if (!_isAsleepStage(point.type)) return false;
  return point.dateTo.difference(point.dateFrom) >=
      const Duration(minutes: 30);
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
