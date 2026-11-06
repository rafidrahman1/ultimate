import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal/core/period/analysis_month_settings_service.dart';
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
  Future<ScreenTimeSummary> loadMonth(DateTime monthStart) async {
    if (!isSupported) return ScreenTimeSummary.empty;
    final now = DateTime.now();
    final nextMonth = DateTime(monthStart.year, monthStart.month + 1);
    final end = nextMonth.isAfter(now)
        ? DateTime(now.year, now.month, now.day + 1)
        : nextMonth;
    final rows = await _channel.invokeMethod<List<Object?>>('queryDaily', {
      'startMs': DateTime(
        monthStart.year,
        monthStart.month,
      ).millisecondsSinceEpoch,
      'endMs': end.millisecondsSinceEpoch,
    });
    return ScreenTimeSummary.fromChannelRows(rows ?? const []);
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
