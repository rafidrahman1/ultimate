import 'dart:math' show atan2, cos, pi, sin;

import 'package:health/health.dart';

import '../../core/period_range.dart';
import 'health_service.dart';
import 'step_counter.dart';

typedef TimeInterval = ({DateTime start, DateTime end});

/// Weekly averages for AI prompts (7-day window, heart rate is current).
class WeeklyHealthSummary {
  const WeeklyHealthSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.avgStepsPerDay,
    required this.avgSleepPerDay,
    required this.avgBedtime,
    required this.avgWakeTime,
    required this.sleepNightsTracked,
    required this.latestHeartRate,
    required this.latestHeartRateTime,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final double avgStepsPerDay;
  final Duration avgSleepPerDay;
  final DateTime? avgBedtime;
  final DateTime? avgWakeTime;
  final int sleepNightsTracked;
  final int? latestHeartRate;
  final DateTime? latestHeartRateTime;

  String get periodRangeLabel => formatPeriodRange(periodStart, periodEnd);

  static const weeklyDayCount = 7;

  factory WeeklyHealthSummary.fromWeeklyFetch(WeeklyHealthFetchResult fetch) {
    final stepValues = fetch.dailySteps.values.toList();
    final avgSteps = stepValues.isEmpty
        ? 0.0
        : stepValues.reduce((a, b) => a + b) / weeklyDayCount;

    final sleepSessions = _sleepSessionsForLastWeek(
      fetch.points,
      fetch.periodStart,
    );
    final avgSleep = sleepSessions.isEmpty
        ? Duration.zero
        : Duration(
            microseconds: sleepSessions
                    .map((s) => s.duration.inMicroseconds)
                    .reduce((a, b) => a + b) ~/
                sleepSessions.length,
          );

    final bedtimes = sleepSessions.map((s) => s.startTime).toList();
    final wakeTimes = sleepSessions.map((s) => s.endTime).toList();
    final heartRate = _latestHeartRate(fetch.points);

    return WeeklyHealthSummary(
      periodStart: fetch.periodStart,
      periodEnd: fetch.periodEnd,
      avgStepsPerDay: avgSteps,
      avgSleepPerDay: avgSleep,
      avgBedtime: _averageBedtime(bedtimes),
      avgWakeTime: _averageWakeTime(wakeTimes),
      sleepNightsTracked: sleepSessions.length,
      latestHeartRate: heartRate?.value,
      latestHeartRateTime: heartRate?.time,
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

class _HeartRateReading {
  const _HeartRateReading(this.value, this.time);

  final int value;
  final DateTime time;
}

_HeartRateReading? _latestHeartRate(List<HealthDataPoint> data) {
  final heartRateData =
      data.where((p) => p.type == HealthDataType.HEART_RATE).toList();
  if (heartRateData.isEmpty) return null;

  heartRateData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
  final latest = heartRateData.first;
  final value = latest.value;
  if (value is! NumericHealthValue) return null;

  return _HeartRateReading(value.numericValue.round(), latest.dateFrom);
}

List<SleepSummary> _sleepSessionsForLastWeek(
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
  if (sleepPoints.isEmpty) return const [];

  final firstDay = DateTime(
    periodStart.year,
    periodStart.month,
    periodStart.day,
  );
  final sessions = <SleepSummary>[];

  for (var offset = 0; offset < WeeklyHealthSummary.weeklyDayCount; offset++) {
    final wakeDay = firstDay.add(Duration(days: offset));
    final session = _sleepForWakeDay(sleepPoints, wakeDay);
    if (session != null) sessions.add(session);
  }

  return sessions;
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

Duration _intervalsDuration(Iterable<TimeInterval> intervals) {
  var total = Duration.zero;
  for (final interval in intervals) {
    total += interval.end.difference(interval.start);
  }
  return total;
}

DateTime? _averageBedtime(List<DateTime> bedtimes) =>
    _averageClockTime(bedtimes, _bedtimeMinutesFromMidnight);

DateTime? _averageWakeTime(List<DateTime> wakeTimes) => _averageClockTime(
      wakeTimes,
      (time) => time.hour * 60.0 + time.minute,
    );

DateTime? _averageClockTime(
  List<DateTime> times,
  double Function(DateTime) minutesFromMidnight,
) {
  if (times.isEmpty) return null;
  const dayMinutes = 24 * 60;
  var sinSum = 0.0;
  var cosSum = 0.0;
  for (final time in times) {
    final angle = 2 * pi * minutesFromMidnight(time) / dayMinutes;
    sinSum += sin(angle);
    cosSum += cos(angle);
  }
  final count = times.length;
  var avgMinutes = atan2(sinSum / count, cosSum / count) * dayMinutes / (2 * pi);
  if (avgMinutes < 0) avgMinutes += dayMinutes;
  return _dateTimeFromMinutes(avgMinutes);
}

double _bedtimeMinutesFromMidnight(DateTime bedtime) {
  final minutes = bedtime.hour * 60.0 + bedtime.minute;
  return minutes < 12 * 60 ? minutes + 24 * 60 : minutes;
}

DateTime _dateTimeFromMinutes(double minutes) {
  final normalized = minutes % (24 * 60);
  final hour = normalized ~/ 60;
  final minute = (normalized % 60).round();
  return DateTime(2000, 1, 1, hour, minute);
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

String formatTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
