import 'package:health/health.dart';

import '../../core/period_range.dart';
import 'health_service.dart';
import 'step_counter.dart';

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
    required this.latestWeightKg,
    required this.latestWeightTime,
    required this.heightMeters,
    required this.heightRecordedTime,
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
  final double? latestWeightKg;
  final DateTime? latestWeightTime;
  final double? heightMeters;
  final DateTime? heightRecordedTime;
  final int? latestHeartRate;
  final DateTime? latestHeartRateTime;

  String get periodRangeLabel => formatPeriodRange(periodStart, periodEnd);

  double? get bmi {
    final weight = latestWeightKg;
    final height = heightMeters;
    if (weight == null || height == null || height <= 0) return null;
    return weight / (height * height);
  }

  factory WeeklyHealthSummary.fromWeeklyFetch(WeeklyHealthFetchResult fetch) {
    const weekDays = 7;
    final stepValues = fetch.dailySteps.values.toList();
    final avgSteps = stepValues.isEmpty
        ? 0.0
        : stepValues.reduce((a, b) => a + b) / weekDays;

    final sleepSessions = _sleepSessionsInPeriod(
      fetch.points,
      fetch.periodStart,
      fetch.periodEnd,
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
    final weight = _latestBodyMetric(fetch.points, HealthDataType.WEIGHT);
    final height = _latestBodyMetric(fetch.points, HealthDataType.HEIGHT);

    return WeeklyHealthSummary(
      periodStart: fetch.periodStart,
      periodEnd: fetch.periodEnd,
      avgStepsPerDay: avgSteps,
      avgSleepPerDay: avgSleep,
      avgBedtime: _averageBedtime(bedtimes),
      avgWakeTime: _averageWakeTime(wakeTimes),
      sleepNightsTracked: sleepSessions.length,
      latestWeightKg: weight?.valueKg,
      latestWeightTime: weight?.time,
      heightMeters: height?.valueMeters,
      heightRecordedTime: height?.time,
      latestHeartRate: heartRate?.value,
      latestHeartRateTime: heartRate?.time,
    );
  }
}

class _BodyMetricReading {
  const _BodyMetricReading({
    required this.valueKg,
    required this.valueMeters,
    required this.time,
  });

  final double? valueKg;
  final double? valueMeters;
  final DateTime time;
}

_BodyMetricReading? _latestBodyMetric(
  List<HealthDataPoint> data,
  HealthDataType type,
) {
  var points = data.where((p) => p.type == type).toList();
  if (points.isEmpty) return null;

  final samsung =
      points.where((p) => isSamsungHealthSource(p.sourceName)).toList();
  if (samsung.isNotEmpty) points = samsung;

  points.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

  for (final point in points) {
    final value = point.value;
    if (value is! NumericHealthValue) continue;

    final numeric = value.numericValue.toDouble();
    if (type == HealthDataType.WEIGHT) {
      final kg = _toKilograms(numeric, point.unit);
      if (kg != null) {
        return _BodyMetricReading(
          valueKg: kg,
          valueMeters: null,
          time: point.dateFrom,
        );
      }
    } else if (type == HealthDataType.HEIGHT) {
      final meters = _toMeters(numeric, point.unit);
      if (meters != null) {
        return _BodyMetricReading(
          valueKg: null,
          valueMeters: meters,
          time: point.dateFrom,
        );
      }
    }
  }
  return null;
}

double? _toKilograms(double value, HealthDataUnit unit) => switch (unit) {
      HealthDataUnit.KILOGRAM => value,
      HealthDataUnit.GRAM => value / 1000,
      HealthDataUnit.POUND => value * 0.45359237,
      HealthDataUnit.OUNCE => value * 0.0283495231,
      HealthDataUnit.STONE => value * 6.35029318,
      _ => null,
    };

double? _toMeters(double value, HealthDataUnit unit) => switch (unit) {
      HealthDataUnit.METER => value,
      HealthDataUnit.INCH => value * 0.0254,
      HealthDataUnit.FOOT => value * 0.3048,
      HealthDataUnit.YARD => value * 0.9144,
      HealthDataUnit.MILE => value * 1609.34,
      _ => null,
    };

String formatWeightKg(double? kg) =>
    kg != null ? kg.toStringAsFixed(1) : '--';

String formatBmi(double? bmi) => bmi != null ? bmi.toStringAsFixed(1) : '--';

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

List<SleepSummary> _sleepSessionsInPeriod(
  List<HealthDataPoint> data,
  DateTime periodStart,
  DateTime periodEnd,
) {
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
  if (sleepPoints.isEmpty) return const [];

  final sessions = <SleepSummary>[];
  final wakeDays = <DateTime>{};
  var day = DateTime(periodStart.year, periodStart.month, periodStart.day);
  final lastDay = DateTime(
    periodEnd.year,
    periodEnd.month,
    periodEnd.day,
  );

  while (!day.isAfter(lastDay)) {
    final session = _sleepForWakeDay(sleepPoints, day);
    if (session != null) {
      final wakeDay = DateTime(day.year, day.month, day.day);
      if (wakeDays.add(wakeDay)) sessions.add(session);
    }
    day = day.add(const Duration(days: 1));
  }

  return sessions;
}

SleepSummary? _sleepForWakeDay(
  List<HealthDataPoint> sleepPoints,
  DateTime wakeDay,
) {
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

  return SleepSummary.fromData(inWindow);
}

DateTime? _averageBedtime(List<DateTime> bedtimes) {
  if (bedtimes.isEmpty) return null;
  final totalMinutes = bedtimes
      .map(_bedtimeMinutesFromMidnight)
      .reduce((a, b) => a + b);
  return _dateTimeFromMinutes(totalMinutes / bedtimes.length);
}

DateTime? _averageWakeTime(List<DateTime> wakeTimes) {
  if (wakeTimes.isEmpty) return null;
  final totalMinutes = wakeTimes
      .map((t) => t.hour * 60.0 + t.minute)
      .reduce((a, b) => a + b);
  return _dateTimeFromMinutes(totalMinutes / wakeTimes.length);
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
