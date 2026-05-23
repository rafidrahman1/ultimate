import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import 'step_counter.dart';

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
    this.stepsFromHealthConnectOnly = false,
  });

  final List<HealthDataPoint> points;
  final int todaySteps;

  /// True when today's steps came only from Health Connect aggregate/records,
  /// not a higher per-source total (Samsung app may still show more until sync).
  final bool stepsFromHealthConnectOnly;
}

class HealthService {
  final Health _health = Health();

  static const _coreTypes = [
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

  static const _optionalTypes = [
    HealthDataType.DISTANCE_DELTA,
  ];

  static const _types = [..._coreTypes, ..._optionalTypes];

  static final _permissions =
      List.filled(_types.length, HealthDataAccess.READ);
  static final _corePermissions =
      List.filled(_coreTypes.length, HealthDataAccess.READ);

  Future<bool> authorize() async {
    await Permission.activityRecognition.request();
    await Permission.location.request();

    bool? hasPermissions;
    try {
      hasPermissions = await _health.hasPermissions(_types, permissions: _permissions);
    } catch (e) {
      debugPrint('Error checking full health permissions, falling back to core: $e');
      try {
        hasPermissions = await _health.hasPermissions(
          _coreTypes,
          permissions: _corePermissions,
        );
      } catch (coreError) {
        debugPrint('Error checking core health permissions: $coreError');
        return false;
      }
    }

    if (hasPermissions == false) {
      try {
        hasPermissions = await _health.requestAuthorization(
          _types,
          permissions: _permissions,
        );
      } catch (e) {
        debugPrint('Error requesting full health authorization, retrying core: $e');
        try {
          hasPermissions = await _health.requestAuthorization(
            _coreTypes,
            permissions: _corePermissions,
          );
        } catch (coreError) {
          debugPrint('Error requesting core health authorization: $coreError');
          return false;
        }
      }
    }
    return hasPermissions ?? false;
  }

  Future<HealthFetchResult> fetchHealthData() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final yesterday = now.subtract(const Duration(days: 1));

    List<HealthDataPoint> healthData;
    try {
      healthData = await _health.getHealthDataFromTypes(
        startTime: yesterday,
        endTime: now,
        types: _types,
      );
    } catch (e) {
      debugPrint('Error fetching extended health types, retrying core set: $e');
      healthData = await _health.getHealthDataFromTypes(
        startTime: yesterday,
        endTime: now,
        types: _coreTypes,
      );
    }

    final points = _health.removeDuplicates(healthData);
    final stepResult = await _fetchTodaySteps(midnight, now);

    return HealthFetchResult(
      points: points,
      todaySteps: stepResult.steps,
      stepsFromHealthConnectOnly: stepResult.healthConnectOnly,
    );
  }

  Future<({int steps, bool healthConnectOnly})> _fetchTodaySteps(
    DateTime midnight,
    DateTime now,
  ) async {
    var aggregated = 0;
    try {
      aggregated = await _health.getTotalStepsInInterval(midnight, now) ?? 0;
    } catch (e) {
      debugPrint('Error fetching aggregated step count: $e');
    }

    List<HealthDataPoint> stepPoints = [];
    try {
      stepPoints = _health.removeDuplicates(
        await _health.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: midnight,
          endTime: now,
        ),
      );
    } catch (e) {
      debugPrint('Error fetching step records: $e');
    }

    final resolved = resolveTodaySteps(
      aggregatedSteps: aggregated,
      stepPoints: stepPoints,
      start: midnight,
      end: now,
    );

    final samsungSteps = sumStepsForSources(
      stepPoints,
      midnight,
      now,
      samsungHealthSourceFragments,
    );
    final maxBySource = maxStepsBySource(stepPoints, midnight, now);

    final healthConnectOnly = resolved <= aggregated &&
        samsungSteps == 0 &&
        maxBySource <= aggregated;

    return (steps: resolved, healthConnectOnly: healthConnectOnly);
  }
}
