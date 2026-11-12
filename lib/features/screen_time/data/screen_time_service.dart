import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/period/analysis_month_settings_service.dart';
import 'package:personal/core/storage/json_file_cache.dart';
import 'package:personal/features/analysis/period_comparison.dart';
import 'package:personal/features/screen_time/data/phone_habits_models.dart';
import 'package:personal/features/screen_time/data/screen_time_models.dart';

/// Reads per-app screen time from Android's usage stats (the data behind
/// Digital Wellbeing). Needs the "Usage access" special permission.
class ScreenTimeService {
  static const _channel = MethodChannel('com.redpanda.personal/usage_stats');

  bool get isSupported => Platform.isAndroid;

  Future<bool> hasAccess() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('hasAccess') ?? false;
  }

  Future<void> openAccessSettings() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('openSettings');
  }

  /// Usage for every local day in [monthStart]'s month, up to now.
  Future<ScreenTimeSummary> loadMonth(DateTime monthStart) {
    return loadRange(
      DateTime(monthStart.year, monthStart.month),
      DateTime(monthStart.year, monthStart.month + 1),
    );
  }

  /// Usage for each local day from [start] up to (not including)
  /// [endExclusive], never reaching past the end of today.
  Future<ScreenTimeSummary> loadRange(
    DateTime start,
    DateTime endExclusive,
  ) async {
    if (!isSupported) return ScreenTimeSummary.empty;
    final now = clock.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final end = endExclusive.isAfter(tomorrow) ? tomorrow : endExclusive;
    final from = DateTime(start.year, start.month, start.day);
    if (!end.isAfter(from)) return ScreenTimeSummary.empty;
    final rows = await _channel.invokeMethod<List<Object?>>('queryDaily', {
      'startMs': from.millisecondsSinceEpoch,
      'endMs': end.millisecondsSinceEpoch,
    });
    return ScreenTimeSummary.fromChannelRows(rows ?? const []);
  }

  static const _phoneCacheKey = 'phone_habits_v1';
  static const _phoneQueryDays = 60;
  static const _phoneKeepDays = 400;

  /// Pickups and first/last use per day. Reads what Android still has and
  /// adds it to the days saved on earlier runs, so the history grows past
  /// the few days of events Android keeps.
  Future<PhoneHabits> loadPhoneHabits() async {
    if (!isSupported) return PhoneHabits.empty;
    final now = clock.now();
    final rows = await _channel.invokeMethod<List<Object?>>('queryPhoneDays', {
      'startMs': DateTime(
        now.year,
        now.month,
        now.day - (_phoneQueryDays - 1),
      ).millisecondsSinceEpoch,
      'endMs': DateTime(
        now.year,
        now.month,
        now.day + 1,
      ).millisecondsSinceEpoch,
    });
    final fresh = PhoneHabits.fromRows(rows ?? const []);
    var saved = PhoneHabits.empty;
    try {
      final json = await JsonFileCache.instance.read(_phoneCacheKey);
      if (json != null) saved = PhoneHabits.fromJson(json);
    } catch (error) {
      AppLog.warn('Could not read saved phone habits: $error');
    }
    final merged = saved
        .mergedWith(fresh)
        .since(DateTime(now.year, now.month, now.day - _phoneKeepDays));
    if (!fresh.isEmpty) {
      try {
        await JsonFileCache.instance.write(_phoneCacheKey, merged.toJson());
      } catch (error) {
        AppLog.warn('Could not save phone habits: $error');
      }
    }
    return merged;
  }
}

final screenTimeServiceProvider = Provider((ref) => ScreenTimeService());

class ScreenTimeState {
  const ScreenTimeState({required this.hasAccess, required this.summary});

  final bool hasAccess;
  final ScreenTimeSummary summary;
}

/// Screen time for the selected analysis month; reloads when it changes.
final screenTimeProvider = FutureProvider.autoDispose<ScreenTimeState>((
  ref,
) async {
  final service = ref.watch(screenTimeServiceProvider);
  final month = ref.watch(selectedAnalysisMonthProvider);
  if (!await service.hasAccess()) {
    return const ScreenTimeState(
      hasAccess: false,
      summary: ScreenTimeSummary.empty,
    );
  }
  return ScreenTimeState(
    hasAccess: true,
    summary: await service.loadMonth(month),
  );
});

/// Screen time for the analysis period and the one before it, for the
/// dashboard and the export. Empty (never an error) when access is missing.
class ScreenTimeAnalysisData {
  const ScreenTimeAnalysisData({
    this.current = ScreenTimeSummary.empty,
    this.previous = ScreenTimeSummary.empty,
  });

  static const none = ScreenTimeAnalysisData();

  final ScreenTimeSummary current;
  final ScreenTimeSummary previous;
}

final screenTimeForAnalysisProvider =
    FutureProvider.autoDispose<ScreenTimeAnalysisData>((ref) async {
      final service = ref.watch(screenTimeServiceProvider);
      final period = ref.watch(analysisPeriodProvider);
      try {
        if (!await service.hasAccess()) return ScreenTimeAnalysisData.none;
        final previous = period.previousComparablePeriod;
        DateTime after(DateTime d) => DateTime(d.year, d.month, d.day + 1);
        final current = await service.loadRange(
          period.dataMonthStart,
          after(period.dataMonthEnd),
        );
        final before = await service.loadRange(
          previous.dataMonthStart,
          after(previous.dataMonthEnd),
        );
        return ScreenTimeAnalysisData(current: current, previous: before);
      } catch (error) {
        AppLog.warn('Screen time unavailable for analysis: $error');
        return ScreenTimeAnalysisData.none;
      }
    });

/// The last 60 days, for forecasts that look across months.
final screenTimeRecentProvider = FutureProvider<ScreenTimeSummary>((ref) async {
  final service = ref.watch(screenTimeServiceProvider);
  try {
    if (!await service.hasAccess()) return ScreenTimeSummary.empty;
    final now = clock.now();
    return await service.loadRange(
      DateTime(now.year, now.month, now.day - 59),
      DateTime(now.year, now.month, now.day + 1),
    );
  } catch (error) {
    AppLog.warn('Recent screen time unavailable: $error');
    return ScreenTimeSummary.empty;
  }
});

/// Pickups and first/last phone use per day (empty without usage access).
final phoneHabitsProvider = FutureProvider<PhoneHabits>((ref) async {
  final service = ref.watch(screenTimeServiceProvider);
  try {
    if (!await service.hasAccess()) return PhoneHabits.empty;
    return await service.loadPhoneHabits();
  } catch (error) {
    AppLog.warn('Phone habits unavailable: $error');
    return PhoneHabits.empty;
  }
});
