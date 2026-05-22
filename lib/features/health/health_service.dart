import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

final healthServiceProvider = Provider((ref) => HealthService());

final healthAuthorizationProvider = FutureProvider<bool>((ref) async {
  final healthService = ref.watch(healthServiceProvider);
  return healthService.authorize();
});

final healthDataProvider = FutureProvider<HealthFetchResult>((ref) async {
  final isAuthorized = await ref.watch(healthAuthorizationProvider.future);
  if (!isAuthorized) return const HealthFetchResult(points: [], todaySteps: 0);

  final healthService = ref.watch(healthServiceProvider);
  return healthService.fetchHealthData();
});

class HealthFetchResult {
  const HealthFetchResult({
    required this.points,
    required this.todaySteps,
  });

  final List<HealthDataPoint> points;
  final int todaySteps;
}

class HealthService {
  final Health _health = Health();

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.WORKOUT,
  ];

  static final _permissions =
      List.filled(_types.length, HealthDataAccess.READ);

  Future<bool> authorize() async {
    await Permission.activityRecognition.request();
    await Permission.location.request();

    var hasPermissions =
        await _health.hasPermissions(_types, permissions: _permissions);

    if (hasPermissions == false) {
      try {
        hasPermissions =
            await _health.requestAuthorization(_types, permissions: _permissions);
      } catch (e) {
        debugPrint('Error requesting health authorization: $e');
        return false;
      }
    }
    return hasPermissions ?? false;
  }

  Future<HealthFetchResult> fetchHealthData() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final yesterday = now.subtract(const Duration(days: 1));

    final healthData = await _health.getHealthDataFromTypes(
      startTime: yesterday,
      endTime: now,
      types: _types,
    );

    final points = _health.removeDuplicates(healthData);
    final todaySteps = await _fetchTodaySteps(midnight, now, points);

    return HealthFetchResult(points: points, todaySteps: todaySteps);
  }

  Future<int> _fetchTodaySteps(
    DateTime midnight,
    DateTime now,
    List<HealthDataPoint> points,
  ) async {
    try {
      return await _health.getTotalStepsInInterval(midnight, now) ?? 0;
    } catch (e) {
      debugPrint('Error fetching step count: $e');
      return _sumStepsForInterval(points, midnight, now);
    }
  }

  static int _sumStepsForInterval(
    List<HealthDataPoint> data,
    DateTime start,
    DateTime end,
  ) {
    var total = 0.0;
    for (final point in data.where((p) => p.type == HealthDataType.STEPS)) {
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
}
