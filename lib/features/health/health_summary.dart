import 'package:health/health.dart';

import '../../core/period_range.dart';
import 'health_service.dart';

class HealthSummary {
  const HealthSummary({
    required this.totalSteps,
    required this.latestHeartRate,
    required this.latestHeartRateTime,
    required this.sleep,
    required this.workoutCount,
    required this.totalWorkoutCalories,
    required this.walkedDuration,
    required this.walkedDistanceKm,
  });

  final int totalSteps;
  final int? latestHeartRate;
  final DateTime? latestHeartRateTime;
  final SleepSummary? sleep;
  final int workoutCount;
  final int totalWorkoutCalories;
  final Duration walkedDuration;
  final double walkedDistanceKm;

  factory HealthSummary.fromData(
    List<HealthDataPoint> data, {
    required int todaySteps,
  }) {
    final workoutPoints =
        data.where((p) => p.type == HealthDataType.WORKOUT).toList();
    final walkingWorkoutPoints = workoutPoints.where(_isWalkingWorkout).toList();
    final distanceFallbackKm = workoutPoints.isEmpty
        ? _sumDistanceKmFromDistanceDelta(data)
        : 0.0;
    final inferredWalking = workoutPoints.isEmpty
        ? _inferWalkingFromSteps(data, todaySteps: todaySteps)
        : _InferredWalkingSummary.empty;
    final hasStructuredExerciseFallback =
        distanceFallbackKm > 0;
    final inferredSessionCount = hasStructuredExerciseFallback
        ? 1
        : inferredWalking.sessionCount;
    final walkedDurationFallback = distanceFallbackKm > 0
        ? _estimateDurationFromDistanceKm(distanceFallbackKm)
        : inferredWalking.duration;
    final walkedDistanceFallback = distanceFallbackKm > 0
        ? distanceFallbackKm
        : inferredWalking.distanceKm;
    final inferredCalories = distanceFallbackKm > 0
        ? _estimateCaloriesFromDistanceKm(distanceFallbackKm)
        : inferredWalking.calories > 0
        ? inferredWalking.calories
        : _estimateCaloriesFromDuration(walkedDurationFallback);

    return HealthSummary(
      totalSteps: todaySteps,
      latestHeartRate: _latestHeartRate(data)?.value,
      latestHeartRateTime: _latestHeartRate(data)?.time,
      sleep: SleepSummary.fromData(data),
      workoutCount: workoutPoints.length + inferredSessionCount,
      totalWorkoutCalories:
          _sumWorkoutCalories(workoutPoints) + inferredCalories,
      walkedDuration:
          _sumWorkoutDuration(walkingWorkoutPoints) + walkedDurationFallback,
      walkedDistanceKm:
          _sumWorkoutDistanceKm(walkingWorkoutPoints) + walkedDistanceFallback,
    );
  }
}

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
    required this.workoutCountPerWeek,
    required this.totalWorkoutKm,
    required this.avgWorkoutTimePerDay,
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
  final int workoutCountPerWeek;
  final double totalWorkoutKm;
  final Duration avgWorkoutTimePerDay;
  final int? latestHeartRate;
  final DateTime? latestHeartRateTime;

  String get periodRangeLabel => formatPeriodRange(periodStart, periodEnd);

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

    final weekSummary = HealthSummary.fromData(
      fetch.points,
      todaySteps: fetch.todaySteps,
    );

    final totalWorkoutDuration = weekSummary.walkedDuration;
    final avgWorkoutPerDay = Duration(
      microseconds: totalWorkoutDuration.inMicroseconds ~/ weekDays,
    );

    return WeeklyHealthSummary(
      periodStart: fetch.periodStart,
      periodEnd: fetch.periodEnd,
      avgStepsPerDay: avgSteps,
      avgSleepPerDay: avgSleep,
      avgBedtime: _averageBedtime(bedtimes),
      avgWakeTime: _averageWakeTime(wakeTimes),
      sleepNightsTracked: sleepSessions.length,
      workoutCountPerWeek: weekSummary.workoutCount,
      totalWorkoutKm: weekSummary.walkedDistanceKm,
      avgWorkoutTimePerDay: avgWorkoutPerDay,
      latestHeartRate: weekSummary.latestHeartRate,
      latestHeartRateTime: weekSummary.latestHeartRateTime,
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

int _sumWorkoutCalories(List<HealthDataPoint> workoutPoints) {
  var total = 0.0;
  for (final point in workoutPoints) {
    final value = point.value;
    if (value is WorkoutHealthValue) {
      total += value.totalEnergyBurned ?? 0;
    }
  }
  return total.round();
}

double _sumDistanceKmFromDistanceDelta(List<HealthDataPoint> data) {
  var meters = 0.0;
  for (final point in data.where((p) => p.type == HealthDataType.DISTANCE_DELTA)) {
    final value = point.value;
    if (value is! NumericHealthValue) continue;
    meters += value.numericValue.toDouble();
  }
  return meters / 1000;
}

Duration _sumWorkoutDuration(List<HealthDataPoint> workoutPoints) {
  var total = Duration.zero;
  for (final point in workoutPoints) {
    total += point.dateTo.difference(point.dateFrom);
  }
  return total;
}

double _sumWorkoutDistanceKm(List<HealthDataPoint> workoutPoints) {
  var totalKm = 0.0;
  for (final point in workoutPoints) {
    final value = point.value;
    if (value is! WorkoutHealthValue) continue;
    if (value.totalDistance == null) continue;

    final distance = value.totalDistance!.toDouble();
    final unit = value.totalDistanceUnit ?? HealthDataUnit.METER;
    totalKm += switch (unit) {
      HealthDataUnit.METER => distance / 1000,
      HealthDataUnit.MILE => distance * 1.60934,
      HealthDataUnit.FOOT => distance * 0.0003048,
      HealthDataUnit.YARD => distance * 0.0009144,
      _ => 0,
    };
  }
  return totalKm;
}

int _estimateCaloriesFromDuration(Duration duration) {
  // Rough walking estimate for fallback-only records.
  final minutes = duration.inMinutes;
  if (minutes <= 0) return 0;
  return (minutes * 6).round();
}

Duration _estimateDurationFromDistanceKm(double distanceKm) {
  if (distanceKm <= 0) return Duration.zero;
  // Assume relaxed walking pace (~5.2 km/h) when only distance is available.
  final estimatedMinutes = ((distanceKm / 5.2) * 60).round();
  return Duration(minutes: estimatedMinutes);
}

int _estimateCaloriesFromDistanceKm(double distanceKm) {
  if (distanceKm <= 0) return 0;
  // Approximate Samsung Health walking energy for moderate pace.
  const kcalPerKm = 86.0;
  return (distanceKm * kcalPerKm).round();
}

bool _isWalkingWorkout(HealthDataPoint point) {
  final value = point.value;
  if (value is! WorkoutHealthValue) return false;
  return switch (value.workoutActivityType) {
    HealthWorkoutActivityType.WALKING => true,
    HealthWorkoutActivityType.WALKING_TREADMILL => true,
    _ => false,
  };
}

_InferredWalkingSummary _inferWalkingFromSteps(
  List<HealthDataPoint> data, {
  required int todaySteps,
}) {
  const minStepsForFallbackSession = 2500;
  const estimatedStrideMeters = 0.78;
  const estimatedCaloriesPerStep = 0.04;

  // Some providers sync walks only as step records, not WORKOUT sessions.
  final stepPoints = data.where((p) => p.type == HealthDataType.STEPS).toList();
  if (stepPoints.isEmpty) {
    if (todaySteps < minStepsForFallbackSession) return _InferredWalkingSummary.empty;
    return _fallbackFromStepTotal(
      steps: todaySteps.toDouble(),
      estimatedStrideMeters: estimatedStrideMeters,
      estimatedCaloriesPerStep: estimatedCaloriesPerStep,
    );
  }

  final candidateWindows = <({DateTime start, DateTime end, double steps})>[];

  for (final point in stepPoints) {
    final value = point.value;
    if (value is! NumericHealthValue) continue;

    final steps = value.numericValue.toDouble();
    final duration = point.dateTo.difference(point.dateFrom);
    final minutes = duration.inMinutes;

    // Ignore tiny fragments and full-day aggregate rows.
    if (minutes < 20 || minutes > 150) continue;
    if (steps < 1200) continue;

    final cadence = steps / minutes;
    if (cadence < 40) continue;

    candidateWindows.add((start: point.dateFrom, end: point.dateTo, steps: steps));
  }

  if (candidateWindows.isEmpty) {
    if (todaySteps < minStepsForFallbackSession) return _InferredWalkingSummary.empty;
    return _fallbackFromStepTotal(
      steps: todaySteps.toDouble(),
      estimatedStrideMeters: estimatedStrideMeters,
      estimatedCaloriesPerStep: estimatedCaloriesPerStep,
    );
  }

  candidateWindows.sort((a, b) => a.start.compareTo(b.start));
  final merged = <({DateTime start, DateTime end, double steps})>[];

  for (final window in candidateWindows) {
    if (merged.isEmpty) {
      merged.add(window);
      continue;
    }

    final last = merged.last;
    final overlaps = window.start.isBefore(last.end);
    final isContinuous =
        overlaps ||
        !window.start.isAfter(last.end.add(const Duration(minutes: 10)));

    if (isContinuous) {
      final mergedSteps = overlaps
          ? (window.steps > last.steps ? window.steps : last.steps)
          : (last.steps + window.steps);
      if (window.end.isAfter(last.end)) {
        merged[merged.length - 1] = (
          start: last.start,
          end: window.end,
          steps: mergedSteps,
        );
      } else {
        merged[merged.length - 1] = (
          start: last.start,
          end: last.end,
          steps: mergedSteps,
        );
      }
      continue;
    }

    merged.add(window);
  }

  var totalDuration = Duration.zero;
  var totalSteps = 0.0;
  for (final session in merged) {
    totalDuration += session.end.difference(session.start);
    totalSteps += session.steps;
  }

  return _InferredWalkingSummary(
    sessionCount: merged.length,
    duration: totalDuration,
    distanceKm: (totalSteps * estimatedStrideMeters) / 1000,
    calories: (totalSteps * estimatedCaloriesPerStep).round(),
  );
}

_InferredWalkingSummary _fallbackFromStepTotal({
  required double steps,
  required double estimatedStrideMeters,
  required double estimatedCaloriesPerStep,
}) {
  final estimatedMinutes = (steps / 83).round().clamp(20, 180);
  return _InferredWalkingSummary(
    sessionCount: 1,
    duration: Duration(minutes: estimatedMinutes),
    distanceKm: (steps * estimatedStrideMeters) / 1000,
    calories: (steps * estimatedCaloriesPerStep).round(),
  );
}

class _InferredWalkingSummary {
  const _InferredWalkingSummary({
    required this.sessionCount,
    required this.duration,
    required this.distanceKm,
    required this.calories,
  });

  static const empty = _InferredWalkingSummary(
    sessionCount: 0,
    duration: Duration.zero,
    distanceKm: 0,
    calories: 0,
  );

  final int sessionCount;
  final Duration duration;
  final double distanceKm;
  final int calories;
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

String formatDistanceKm(double distanceKm) => distanceKm.toStringAsFixed(1);
