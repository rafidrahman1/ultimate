import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/core/data_cache_service.dart';

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
  });

  final List<HealthDataPoint> points;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int dayCount;

  static MonthlyHealthFetchResult empty({AnalysisPeriod? period}) {
    final resolved = period ?? AnalysisPeriod.forDataMonth(DateTime.now());
    return MonthlyHealthFetchResult(
      points: const [],
      periodStart: resolved.dataMonthStart,
      periodEnd: resolved.dataMonthEnd,
      dayCount: resolved.daysInDataMonth,
    );
  }

  bool get hasData => points.isNotEmpty;
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
    } catch (_) {
      // Ignore: older Health Connect versions or denied history permission.
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
    } catch (_) {
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
    } catch (_) {
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
      } catch (_) {}
    }
    return points;
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
    );
  }
}
