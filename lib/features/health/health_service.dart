import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/core/data_cache_service.dart';
import 'package:personal/features/health/step_counter.dart';

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
        cached.periodStart == period.dataMonthStart &&
        cached.periodEnd == period.dataMonthEnd) {
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

    await DataCacheService.instance.clearMonthlyHealth();
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

  bool _configured = false;

  static const _maxStepRecordReadsPerDay = 8;

  static DateTime _endOfCalendarDay(DateTime dayStart) {
    return DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day,
      23,
      59,
      59,
      999,
      999,
    );
  }

  /// Inclusive step query end for a calendar day, capped by [cap].
  static DateTime _stepQueryEnd(DateTime dayStart, DateTime cap) {
    final dayEnd = _endOfCalendarDay(dayStart);
    return cap.isBefore(dayEnd) ? cap : dayEnd;
  }

  static const _sleepTypes = [
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
  ];

  static const _workoutTypes = [
    HealthDataType.WORKOUT,
  ];

  static const _optionalTypes = [
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  static const _coreTypes = [
    HealthDataType.STEPS,
    ..._sleepTypes,
    ..._workoutTypes,
  ];

  static const _types = [..._coreTypes, ..._optionalTypes];

  static final _permissions =
      List.filled(_types.length, HealthDataAccess.READ);
  static final _corePermissions =
      List.filled(_coreTypes.length, HealthDataAccess.READ);
  static final _optionalPermissions =
      List.filled(_optionalTypes.length, HealthDataAccess.READ);

  /// The plugin must be configured once before any other call (health >= 12).
  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Requests access to data older than Health Connect's default 30-day window.
  ///
  /// Requires the `READ_HEALTH_DATA_HISTORY` manifest permission. Failures are
  /// non-fatal: data-type access still works, just limited to the last 30 days.
  Future<void> _ensureHistoryAccess() async {
    try {
      if (!await _health.isHealthConnectAvailable()) return;
      if (!await _health.isHealthDataHistoryAvailable()) return;
      if (await _health.isHealthDataHistoryAuthorized()) return;
      await _health.requestHealthDataHistoryAuthorization();
    } catch (_) {
      // Ignore: older Health Connect versions or denied history permission.
    }
  }

  Future<bool> authorize() async {
    await _ensureConfigured();
    await Permission.activityRecognition.request();
    await Permission.location.request();

    var granted = await _requestPermissions(_types, _permissions);
    if (!granted) {
      granted = await _requestPermissions(_coreTypes, _corePermissions);
    }
    if (granted) {
      await _requestPermissions(_optionalTypes, _optionalPermissions);
      await _ensureHistoryAccess();
    }
    return granted;
  }

  Future<bool> _requestPermissions(
    List<HealthDataType> types,
    List<HealthDataAccess> permissions,
  ) async {
    try {
      await _health.requestAuthorization(types, permissions: permissions);
      return await _health.hasPermissions(types, permissions: permissions) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<HealthFetchResult> fetchHealthData() async {
    await _ensureConfigured();
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
    DateTime to, {
    void Function()? onRead,
  }) async {
    if (!from.isBefore(to)) return const [];
    onRead?.call();
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

  Future<int> _fetchAggregatedSteps(DateTime start, DateTime end) async {
    if (!start.isBefore(end)) return 0;
    try {
      return await _health.getTotalStepsInInterval(start, end) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// One retry helps when Health Connect quota refills between rapid calls.
  Future<int> _fetchAggregatedStepsWithRetry(
    DateTime start,
    DateTime end,
  ) async {
    final first = await _fetchAggregatedSteps(start, end);
    if (first > 0) return first;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _fetchAggregatedSteps(start, end);
  }

  /// Complete past days: aggregate plus a single day-wide record read.
  ///
  /// The Health Connect aggregate dedupes across sources and is often lower
  /// than Samsung Health's own per-source total. Taking the max of the
  /// aggregate and the per-source record sums (same as today's resolution)
  /// keeps monthly step averages aligned with the Samsung Health app. Uses one
  /// day-wide read (no bisection) so quota stays well within limits.
  Future<int> _fetchStepsForHistoricalDay(
    DateTime dayStart,
    DateTime queryEnd,
  ) async {
    final aggregated =
        await _fetchAggregatedStepsWithRetry(dayStart, queryEnd);

    final records = await _readStepsInRange(dayStart, queryEnd);
    if (records.isEmpty) return aggregated;

    return resolveTodaySteps(
      aggregatedSteps: aggregated,
      stepPoints: records,
      start: dayStart,
      end: queryEnd,
    );
  }

  Future<List<HealthDataPoint>> _fetchWorkoutPoints(
    DateTime fetchStart,
    DateTime fetchEnd,
  ) async {
    if (!fetchStart.isBefore(fetchEnd)) return const [];
    try {
      return await _health.getHealthDataFromTypes(
        startTime: fetchStart,
        endTime: fetchEnd,
        types: _workoutTypes,
      );
    } catch (_) {
      return const [];
    }
  }

  /// Loads sleep types independently so one failing type does not drop all nights.
  Future<List<HealthDataPoint>> _fetchSleepPoints(
    DateTime fetchStart,
    DateTime fetchEnd,
  ) async {
    if (!fetchStart.isBefore(fetchEnd)) return const [];

    final points = <HealthDataPoint>[];
    for (final type in _sleepTypes) {
      try {
        final chunk = await _health.getHealthDataFromTypes(
          startTime: fetchStart,
          endTime: fetchEnd,
          types: [type],
        );
        points.addAll(chunk);
      } catch (_) {}
    }
    return points;
  }

  /// Fetches step records, bisecting the interval when Health Connect rejects
  /// a corrupt record (startTime >= endTime) anywhere in the range.
  Future<List<HealthDataPoint>> _fetchStepRecords(
    DateTime start,
    DateTime end, {
    required int aggregatedSteps,
    int maxRecordReads = _maxStepRecordReadsPerDay,
  }) async {
    var readsRemaining = maxRecordReads;
    var preferBisection = false;

    void consumeReadBudget() {
      if (readsRemaining > 0) readsRemaining--;
    }

    Future<List<HealthDataPoint>> fetchResilient(
      DateTime from,
      DateTime to, {
      bool skipInitialRead = false,
    }) async {
      if (readsRemaining <= 0) return const [];

      if (!skipInitialRead) {
        final direct = await _readStepsInRange(from, to, onRead: consumeReadBudget);
        if (direct.isNotEmpty) return direct;
      }

      // Plugin returns empty when readRecords hits an invalid StepsRecord.
      if (to.difference(from) <= const Duration(hours: 1)) {
        return _readStepsInRange(from, to, onRead: consumeReadBudget);
      }

      final mid = from.add(
        Duration(microseconds: to.difference(from).inMicroseconds ~/ 2),
      );
      if (!mid.isAfter(from) || !to.isAfter(mid)) return const [];

      final left = await fetchResilient(from, mid);
      final right = await fetchResilient(mid, to);
      return [...left, ...right];
    }

    if (!preferBisection) {
      final direct = await _readStepsInRange(start, end, onRead: consumeReadBudget);
      if (direct.isNotEmpty) {
        return _health.removeDuplicates(direct);
      }
      if (aggregatedSteps > 0) {
        preferBisection = true;
      }
    }

    final skipDayWideRead = preferBisection &&
        end.difference(start) > const Duration(hours: 1);
    final points = await fetchResilient(
      start,
      end,
      skipInitialRead: skipDayWideRead,
    );
    return _health.removeDuplicates(points);
  }

  Future<int> _fetchResolvedStepsForDay(
    DateTime dayStart,
    DateTime effectiveEnd, {
    required int maxRecordReads,
  }) async {
    final aggregated = await _fetchAggregatedSteps(dayStart, effectiveEnd);
    final stepPoints = await _fetchStepRecords(
      dayStart,
      effectiveEnd,
      aggregatedSteps: aggregated,
      maxRecordReads: maxRecordReads,
    );
    return resolveTodaySteps(
      aggregatedSteps: aggregated,
      stepPoints: stepPoints,
      start: dayStart,
      end: effectiveEnd,
    );
  }

  Future<({int steps, bool healthConnectOnly})> _fetchTodaySteps(
    DateTime midnight,
    DateTime now,
  ) async {
    final aggregated = await _fetchAggregatedSteps(midnight, now);

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
    await _ensureConfigured();
    final now = DateTime.now();
    final periodStart = period.dataMonthStart;
    final periodEnd = period.dataMonthEnd;
    final todayStart = DateTime(now.year, now.month, now.day);
    final fetchEnd = periodEnd.isAfter(now) ? now : periodEnd;

    // Include the prior calendar day so May 1 wake-day bedtimes are in range.
    final fetchStart = DateTime(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    ).subtract(const Duration(days: 1));

    final workoutPoints = await _fetchWorkoutPoints(fetchStart, fetchEnd);

    // Load steps before sleep so Health Connect quota is not exhausted on sleep
    // types before the first days of the month (which were returning 0 steps).
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

      final queryEnd = _stepQueryEnd(dayStart, effectiveEnd);
      if (dayStart.isBefore(todayStart)) {
        dailySteps[dayStart] =
            await _fetchStepsForHistoricalDay(dayStart, queryEnd);
      } else {
        dailySteps[dayStart] = await _fetchResolvedStepsForDay(
          dayStart,
          queryEnd,
          maxRecordReads: _maxStepRecordReadsPerDay,
        );
      }
    }

    final sleepPoints = _health.removeDuplicates(
      await _fetchSleepPoints(fetchStart, fetchEnd),
    );
    final points = [
      ...sleepPoints,
      ...workoutPoints,
    ];

    return MonthlyHealthFetchResult(
      points: points,
      periodStart: periodStart,
      periodEnd: periodEnd,
      dailySteps: dailySteps,
      dayCount: dayCount,
    );
  }
}
