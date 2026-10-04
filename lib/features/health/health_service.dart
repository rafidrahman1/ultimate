import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/data_cache_service.dart';
import 'package:personal/features/health/vitals_aggregator.dart';
import 'package:personal/features/health/vitals_models.dart';

final healthServiceProvider = Provider((ref) => HealthService());

final healthAuthorizationProvider = FutureProvider<bool>((ref) async {
  final healthService = ref.watch(healthServiceProvider);
  return healthService.authorize();
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
      return MonthlyHealthFetchResult.empty(
        period: ref.read(analysisPeriodProvider),
      );
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
    ref.invalidate(healthAuthorizationProvider);
    final isAuthorized = await ref.read(healthAuthorizationProvider.future);
    if (!isAuthorized) {
      state = AsyncData(
        MonthlyHealthFetchResult.empty(
          period: ref.read(analysisPeriodProvider),
        ),
      );
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

/// One calendar month of health data for analysis prompts.
class MonthlyHealthFetchResult {
  const MonthlyHealthFetchResult({
    required this.points,
    required this.periodStart,
    required this.periodEnd,
    required this.dayCount,
    this.vitals,
  });

  /// Sleep points.
  final List<HealthDataPoint> points;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int dayCount;

  /// Steps, heart rate, workouts and the rest. Null until the user has
  /// connected at least one of those metrics.
  final VitalsSummary? vitals;

  static MonthlyHealthFetchResult empty({AnalysisPeriod? period}) {
    final resolved = period ?? AnalysisPeriod.forDataMonth(DateTime.now());
    return MonthlyHealthFetchResult(
      points: const [],
      periodStart: resolved.dataMonthStart,
      periodEnd: resolved.dataMonthEnd,
      dayCount: resolved.daysInDataMonth,
    );
  }

  bool get hasData => points.isNotEmpty || (vitals?.hasData ?? false);
}

class HealthService {
  final Health _health = Health();

  bool _configured = false;

  static const _sleepTypes = [
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
  ];

  static final _sleepPermissions = List.filled(
    _sleepTypes.length,
    HealthDataAccess.READ,
  );

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Requests access to data older than Health Connect's default 30-day window.
  Future<void> _ensureHistoryAccess() async {
    try {
      if (!await _health.isHealthConnectAvailable()) return;
      if (!await _health.isHealthDataHistoryAvailable()) return;
      if (await _health.isHealthDataHistoryAuthorized()) return;
      await _health.requestHealthDataHistoryAuthorization();
    } catch (error) {
      // Ignore: older Health Connect versions or denied history permission.
      AppLog.warn('Health history authorization unavailable: $error');
    }
  }

  Future<bool> authorize() async {
    await _ensureConfigured();

    final granted = await _requestSleepPermissions();
    if (granted) {
      await _ensureHistoryAccess();
    }
    return granted;
  }

  Future<bool> _requestSleepPermissions() async {
    try {
      await _health.requestAuthorization(
        _sleepTypes,
        permissions: _sleepPermissions,
      );
      return _hasAnySleepPermission();
    } catch (error) {
      AppLog.warn('Failed to request sleep permissions: $error');
      return false;
    }
  }

  Future<bool> _hasAnySleepPermission() async {
    for (final type in _sleepTypes) {
      if (await _hasPermissions([type], const [HealthDataAccess.READ])) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _hasPermissions(
    List<HealthDataType> types,
    List<HealthDataAccess> permissions,
  ) async {
    try {
      return await _health.hasPermissions(types, permissions: permissions) ??
          false;
    } catch (error) {
      AppLog.warn('Failed to check health permissions for $types: $error');
      return false;
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
      } catch (error) {
        AppLog.warn('Failed to fetch sleep data for $type: $error');
      }
    }
    return points;
  }

  static const _metricTypes = <VitalsMetric, HealthDataType>{
    VitalsMetric.steps: HealthDataType.STEPS,
    ...vitalsTypesByMetric,
  };

  /// Which activity and body metrics Health Connect currently lets us read.
  /// Never prompts.
  Future<Set<VitalsMetric>> grantedVitalsMetrics() async {
    await _ensureConfigured();
    final granted = <VitalsMetric>{};
    for (final entry in _metricTypes.entries) {
      if (await _hasPermissions([entry.value], const [HealthDataAccess.READ])) {
        granted.add(entry.key);
      }
    }
    return granted;
  }

  /// Shows Health Connect's permission sheet for every metric and returns the
  /// ones now readable. Call this from a user action, not at startup: each
  /// refusal counts toward Android's limit on re-prompting.
  Future<Set<VitalsMetric>> requestVitalsPermissions() async {
    await _ensureConfigured();
    try {
      final types = _metricTypes.values.toList();
      await _health.requestAuthorization(
        types,
        permissions: List.filled(types.length, HealthDataAccess.READ),
      );
      await _ensureHistoryAccess();
    } catch (error) {
      AppLog.warn('Failed to request vitals permissions: $error');
    }
    return grantedVitalsMetrics();
  }

  /// Daily step totals from the platform's de-duplicated aggregate (phone and
  /// watch don't double count). Days with no steps are left out: zero means
  /// the device wasn't carried, not that you didn't move.
  Future<Map<DateTime, int>> _fetchSteps(
    DateTime periodStart,
    int dayCount,
    DateTime now,
  ) async {
    final first = DateTime(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    );
    final result = <DateTime, int>{};
    for (var offset = 0; offset < dayCount; offset += 7) {
      final batch = <Future<void>>[];
      for (var i = offset; i < offset + 7 && i < dayCount; i++) {
        final day = DateTime(first.year, first.month, first.day + i);
        if (day.isAfter(now)) break;
        final nextDay = DateTime(day.year, day.month, day.day + 1);
        final end = nextDay.isAfter(now) ? now : nextDay;
        batch.add(() async {
          try {
            final steps = await _health.getTotalStepsInInterval(day, end);
            if (steps != null && steps > 0) result[day] = steps;
          } catch (error) {
            AppLog.warn('Failed to read steps for $day: $error');
          }
        }());
      }
      await Future.wait(batch);
    }
    return result;
  }

  /// Reads in short windows: a month of heart-rate samples is one very large
  /// platform message otherwise.
  Future<List<HealthDataPoint>> _fetchVitalsPoints(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async {
    final points = <HealthDataPoint>[];
    var cursor = start;
    while (cursor.isBefore(end)) {
      final next = cursor.add(const Duration(days: 7));
      final windowEnd = next.isAfter(end) ? end : next;
      try {
        points.addAll(
          await _health.getHealthDataFromTypes(
            startTime: cursor,
            endTime: windowEnd,
            types: [type],
          ),
        );
      } catch (error) {
        AppLog.warn('Failed to fetch $type from $cursor: $error');
      }
      cursor = windowEnd;
    }
    return points;
  }

  /// Everything except sleep. Returns null when no metric is connected, and
  /// never throws: sleep must still load if this fails.
  Future<VitalsSummary?> _fetchVitals(
    AnalysisPeriod period,
    DateTime fetchEnd,
  ) async {
    try {
      final granted = await grantedVitalsMetrics();
      if (granted.isEmpty) return null;

      final periodStart = period.dataMonthStart;
      final dayStart = DateTime(
        periodStart.year,
        periodStart.month,
        periodStart.day,
      );
      final steps = granted.contains(VitalsMetric.steps)
          ? await _fetchSteps(periodStart, period.daysInDataMonth, fetchEnd)
          : const <DateTime, int>{};

      final points = <HealthDataPoint>[];
      for (final metric in granted) {
        final type = vitalsTypesByMetric[metric];
        if (type == null) continue;
        // Weight is sparse, so look back far enough to find a baseline.
        final from = metric == VitalsMetric.weight
            ? dayStart.subtract(const Duration(days: 120))
            : dayStart;
        points.addAll(await _fetchVitalsPoints(type, from, fetchEnd));
      }

      final summary = buildVitalsSummary(
        periodStart: periodStart,
        periodEnd: period.dataMonthEnd,
        dayCount: period.daysInDataMonth,
        stepsByDay: steps,
        points: _health.removeDuplicates(points),
        readMetrics: granted,
      );
      AppLog.warn(
        'Vitals read: ${granted.map((m) => m.name).join(', ')}; '
        '${steps.length} step days, ${points.length} points, '
        '${summary.workouts.length} workouts',
      );
      return summary;
    } catch (error) {
      AppLog.warn('Failed to fetch vitals: $error');
      return null;
    }
  }

  Future<MonthlyHealthFetchResult> fetchMonthlyHealthData(
    AnalysisPeriod period,
  ) async {
    await _ensureConfigured();
    final now = DateTime.now();
    final periodStart = period.dataMonthStart;
    final periodEnd = period.dataMonthEnd;
    final fetchEnd = periodEnd.isAfter(now) ? now : periodEnd;

    final fetchStart = DateTime(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    ).subtract(const Duration(days: 1));

    final points = _health.removeDuplicates(
      await _fetchSleepPoints(fetchStart, fetchEnd),
    );

    return MonthlyHealthFetchResult(
      points: points,
      periodStart: periodStart,
      periodEnd: periodEnd,
      dayCount: period.daysInDataMonth,
      vitals: await _fetchVitals(period, fetchEnd),
    );
  }
}
