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

final weeklyHealthDataProvider =
    FutureProvider<WeeklyHealthFetchResult>((ref) async {
  final isAuthorized = await ref.watch(healthAuthorizationProvider.future);
  if (!isAuthorized) {
    return WeeklyHealthFetchResult.empty();
  }

  final healthService = ref.watch(healthServiceProvider);
  return healthService.fetchWeeklyHealthData();
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

/// Seven calendar days of health data for analysis prompts (today + prior 6 days).
class WeeklyHealthFetchResult {
  const WeeklyHealthFetchResult({
    required this.points,
    required this.periodStart,
    required this.periodEnd,
    required this.dailySteps,
    required this.todaySteps,
  });

  final List<HealthDataPoint> points;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Local midnights mapped to step totals for that calendar day.
  final Map<DateTime, int> dailySteps;
  final int todaySteps;

  static WeeklyHealthFetchResult empty() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return WeeklyHealthFetchResult(
      points: const [],
      periodStart: today.subtract(const Duration(days: 6)),
      periodEnd: now,
      dailySteps: const {},
      todaySteps: 0,
    );
  }

  bool get hasData => points.isNotEmpty || dailySteps.values.any((s) => s > 0);
}

class HealthService {
  final Health _health = Health();

  static const _coreTypes = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
  ];

  static const _types = _coreTypes;

  static final _permissions =
      List.filled(_types.length, HealthDataAccess.READ);
  static final _corePermissions =
      List.filled(_coreTypes.length, HealthDataAccess.READ);

  Future<bool> authorize() async {
    await Permission.activityRecognition.request();
    await Permission.location.request();

    bool? hasPermissions;
    try {
      hasPermissions = await _health.hasPermissions(
        _types,
        permissions: _permissions,
      );
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

  Future<WeeklyHealthFetchResult> fetchWeeklyHealthData() async {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final periodStart = todayMidnight.subtract(const Duration(days: 6));
    // Include the evening before the first wake day so bedtimes are not missing.
    final fetchStart = periodStart.subtract(const Duration(hours: 18));

    List<HealthDataPoint> healthData;
    try {
      healthData = await _health.getHealthDataFromTypes(
        startTime: fetchStart,
        endTime: now,
        types: _types,
      );
    } catch (e) {
      debugPrint('Error fetching weekly health types, retrying core set: $e');
      healthData = await _health.getHealthDataFromTypes(
        startTime: fetchStart,
        endTime: now,
        types: _coreTypes,
      );
    }

    final points = _health.removeDuplicates(healthData);

    final dailySteps = <DateTime, int>{};
    for (var offset = 0; offset < 7; offset++) {
      final dayStart = periodStart.add(Duration(days: offset));
      final dayEnd = dayStart.add(const Duration(days: 1));
      final effectiveEnd = dayEnd.isAfter(now) ? now : dayEnd;
      final stepResult = await _fetchTodaySteps(dayStart, effectiveEnd);
      dailySteps[dayStart] = stepResult.steps;
    }

    final todaySteps = dailySteps[todayMidnight] ?? 0;

    return WeeklyHealthFetchResult(
      points: points,
      periodStart: periodStart,
      periodEnd: now,
      dailySteps: dailySteps,
      todaySteps: todaySteps,
    );
  }
}
