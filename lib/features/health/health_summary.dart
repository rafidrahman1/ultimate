import 'package:health/health.dart';

class HealthSummary {
  const HealthSummary({
    required this.totalSteps,
    required this.latestHeartRate,
    required this.latestHeartRateTime,
    required this.sleep,
    required this.workoutCount,
    required this.totalWorkoutCalories,
  });

  final int totalSteps;
  final int? latestHeartRate;
  final DateTime? latestHeartRateTime;
  final SleepSummary? sleep;
  final int workoutCount;
  final int totalWorkoutCalories;

  factory HealthSummary.fromData(
    List<HealthDataPoint> data, {
    required int todaySteps,
  }) {
    return HealthSummary(
      totalSteps: todaySteps,
      latestHeartRate: _latestHeartRate(data)?.value,
      latestHeartRateTime: _latestHeartRate(data)?.time,
      sleep: SleepSummary.fromData(data),
      workoutCount: data.where((p) => p.type == HealthDataType.WORKOUT).length,
      totalWorkoutCalories: _sumWorkoutCalories(data),
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

int _sumWorkoutCalories(List<HealthDataPoint> data) {
  var total = 0.0;
  for (final point in data.where((p) => p.type == HealthDataType.WORKOUT)) {
    final value = point.value;
    if (value is WorkoutHealthValue) {
      total += value.totalEnergyBurned ?? 0;
    }
  }
  return total.round();
}

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

String formatTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
