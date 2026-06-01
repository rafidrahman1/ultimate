import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/analysis_month_settings_service.dart';
import '../../core/analysis_period.dart';
import '../../core/data_cache_service.dart';
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

final monthlyHealthDataProvider =
    AsyncNotifierProvider<MonthlyHealthNotifier, MonthlyHealthFetchResult>(
  MonthlyHealthNotifier.new,
);

class MonthlyHealthNotifier extends AsyncNotifier<MonthlyHealthFetchResult> {
  @override
  Future<MonthlyHealthFetchResult> build() async {
    ref.watch(selectedAnalysisMonthProvider);
    final isAuthorized = await ref.watch(healthAuthorizationProvider.future);
    if (!isAuthorized) {
      return MonthlyHealthFetchResult.empty(period: ref.read(analysisPeriodProvider));
    }

    final period = ref.watch(analysisPeriodProvider);
    final cached = await DataCacheService.instance.loadMonthlyHealth();
    if (cached != null &&
        cached.hasData &&
        cached.periodStart == period.dataMonthStart) {
      return cached;
    }

    return _fetchAndCache();
  }

  Future<void> refresh() async {
    final isAuthorized = await ref.read(healthAuthorizationProvider.future);
    if (!isAuthorized) {
      state = AsyncData(MonthlyHealthFetchResult.empty());
      return;
    }

    state = const AsyncLoading();
    state = AsyncData(await _fetchAndCache());
  }

  Future<MonthlyHealthFetchResult> _fetchAndCache() async {
    final healthService = ref.read(healthServiceProvider);
    final period = ref.read(analysisPeriodProvider);
    final result = await healthService.fetchMonthlyHealthData(period);
    if (result.hasData) {
      await DataCacheService.instance.saveMonthlyHealth(result);
    }
    return result;
  }
}

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

/// One calendar month of health data for analysis prompts.
class MonthlyHealthFetchResult {
  const MonthlyHealthFetchResult({
    required this.points,
    required this.periodStart,
    required this.periodEnd,
    required this.dailySteps,
    required this.dayCount,
  });

  final List<HealthDataPoint> points;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Local midnights mapped to step totals for that calendar day.
  final Map<DateTime, int> dailySteps;
  final int dayCount;

  static MonthlyHealthFetchResult empty({AnalysisPeriod? period}) {
    final resolved = period ?? AnalysisPeriod.forDataMonth(DateTime.now());
    return MonthlyHealthFetchResult(
      points: const [],
      periodStart: resolved.dataMonthStart,
      periodEnd: resolved.dataMonthEnd,
      dailySteps: const {},
      dayCount: resolved.daysInDataMonth,
    );
  }

  bool get hasData => points.isNotEmpty || dailySteps.values.any((s) => s > 0);
}

class HealthService {
  final Health _health = Health();

  /// After Health Connect returns empty step records despite a positive aggregate,
  /// skip whole-day reads and bisect immediately to avoid repeated native errors.
  bool _stepRecordsPreferBisection = false;

  static const _sleepTypes = [
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
  ];

  static const _coreTypes = [
    HealthDataType.STEPS,
    ..._sleepTypes,
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
    } catch (_) {
      try {
        hasPermissions = await _health.hasPermissions(
          _coreTypes,
          permissions: _corePermissions,
        );
      } catch (_) {
        return false;
      }
    }

    if (hasPermissions == false) {
      try {
        hasPermissions = await _health.requestAuthorization(
          _types,
          permissions: _permissions,
        );
      } catch (_) {
        try {
          hasPermissions = await _health.requestAuthorization(
            _coreTypes,
            permissions: _corePermissions,
          );
        } catch (_) {
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
        types: _sleepTypes,
      );
    } catch (_) {
      healthData = const [];
    }

    final points = _health.removeDuplicates(healthData);
    final stepResult = await _fetchTodaySteps(midnight, now);

    return HealthFetchResult(
      points: points,
      todaySteps: stepResult.steps,
      stepsFromHealthConnectOnly: stepResult.healthConnectOnly,
    );
  }

  Future<List<HealthDataPoint>> _readStepsInRange(
    DateTime from,
    DateTime to,
  ) async {
    if (!from.isBefore(to)) return const [];
    try {
      return await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: from,
        endTime: to,
      );
    } catch (_) {
      return const [];
    }
  }

  /// Fetches step records, bisecting the interval when Health Connect rejects
  /// a corrupt record (startTime >= endTime) anywhere in the range.
  Future<List<HealthDataPoint>> _fetchStepRecords(
    DateTime start,
    DateTime end, {
    required int aggregatedSteps,
  }) async {
    Future<List<HealthDataPoint>> fetchResilient(
      DateTime from,
      DateTime to, {
      bool skipInitialRead = false,
    }) async {
      if (!skipInitialRead) {
        final direct = await _readStepsInRange(from, to);
        if (direct.isNotEmpty) return direct;
      }

      // Plugin returns empty when readRecords hits an invalid StepsRecord.
      if (to.difference(from) <= const Duration(hours: 1)) {
        return _readStepsInRange(from, to);
      }

      final mid = from.add(
        Duration(microseconds: to.difference(from).inMicroseconds ~/ 2),
      );
      if (!mid.isAfter(from) || !to.isAfter(mid)) return const [];

      final left = await fetchResilient(from, mid);
      final right = await fetchResilient(mid, to);
      return [...left, ...right];
    }

    if (!_stepRecordsPreferBisection) {
      final direct = await _readStepsInRange(start, end);
      if (direct.isNotEmpty) {
        return _health.removeDuplicates(direct);
      }
      if (aggregatedSteps > 0) {
        _stepRecordsPreferBisection = true;
      }
    }

    final skipDayWideRead = _stepRecordsPreferBisection &&
        end.difference(start) > const Duration(hours: 1);
    final points = await fetchResilient(
      start,
      end,
      skipInitialRead: skipDayWideRead,
    );
    return _health.removeDuplicates(points);
  }

  Future<({int steps, bool healthConnectOnly})> _fetchTodaySteps(
    DateTime midnight,
    DateTime now,
  ) async {
    var aggregated = 0;
    try {
      aggregated = await _health.getTotalStepsInInterval(midnight, now) ?? 0;
    } catch (_) {}

    final stepPoints = await _fetchStepRecords(
      midnight,
      now,
      aggregatedSteps: aggregated,
    );

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

  Future<MonthlyHealthFetchResult> fetchMonthlyHealthData(
    AnalysisPeriod period,
  ) async {
    _stepRecordsPreferBisection = false;
    final now = DateTime.now();
    final periodStart = period.dataMonthStart;
    final periodEnd = period.dataMonthEnd;
    // Include the evening before the first wake day so bedtimes are not missing.
    final fetchStart = periodStart.subtract(const Duration(hours: 18));
    final fetchEnd = periodEnd.isAfter(now) ? now : periodEnd;

    // Steps are loaded per day below; a long STEPS read fails when any
    // corrupt record exists in the range.
    List<HealthDataPoint> healthData;
    try {
      healthData = await _health.getHealthDataFromTypes(
        startTime: fetchStart,
        endTime: fetchEnd,
        types: _sleepTypes,
      );
    } catch (_) {
      healthData = const [];
    }

    final points = _health.removeDuplicates(healthData);

    final dailySteps = <DateTime, int>{};
    final dayCount = period.daysInDataMonth;
    for (var offset = 0; offset < dayCount; offset++) {
      final dayStart = DateTime(
        periodStart.year,
        periodStart.month,
        periodStart.day + offset,
      );
      final dayEnd = dayStart.add(const Duration(days: 1));
      final effectiveEnd = dayEnd.isAfter(fetchEnd) ? fetchEnd : dayEnd;
      if (effectiveEnd.isBefore(dayStart)) continue;
      final stepResult = await _fetchTodaySteps(dayStart, effectiveEnd);
      dailySteps[dayStart] = stepResult.steps;
    }

    return MonthlyHealthFetchResult(
      points: points,
      periodStart: periodStart,
      periodEnd: periodEnd,
      dailySteps: dailySteps,
      dayCount: dayCount,
    );
  }
}
