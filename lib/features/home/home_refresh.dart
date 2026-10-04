import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/app_log.dart';
import 'package:personal/core/prefs.dart';
import 'package:personal/features/calendar/calendar_service.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/features/game_activity/game_activity_service.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/location/location_service.dart';

const _lastRefreshKey = 'home_last_refresh_ms_v1';

/// When Home last re-read every data source (pull-to-refresh), if ever.
final homeLastRefreshProvider =
    NotifierProvider<HomeLastRefreshNotifier, DateTime?>(
      HomeLastRefreshNotifier.new,
    );

class HomeLastRefreshNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    unawaited(_hydrate());
    return null;
  }

  Future<void> _hydrate() async {
    final ms = (await safePrefs())?.getInt(_lastRefreshKey);
    if (ms != null && state == null) {
      state = DateTime.fromMillisecondsSinceEpoch(ms);
    }
  }

  Future<void> mark() async {
    final now = DateTime.now();
    state = now;
    await (await safePrefs())?.setInt(
      _lastRefreshKey,
      now.millisecondsSinceEpoch,
    );
  }
}

/// Re-reads every source without prompting for sign-in. One source failing
/// never stops the others; returns the labels of those that failed.
Future<List<String>> refreshAllSources(WidgetRef ref) async {
  final failed = <String>[];

  Future<void> step(String label, Future<void> Function() run) async {
    try {
      await run();
    } catch (error) {
      AppLog.warn('Refresh failed for $label: $error');
      failed.add(label);
    }
  }

  await Future.wait([
    step(
      'Health',
      () => ref.read(monthlyHealthDataProvider.notifier).refresh(),
    ),
    step(
      'Location',
      () => ref.read(locationSummaryProvider.notifier).loadAuto(),
    ),
    step(
      'Game activity',
      () => ref.read(gameActivitySummaryProvider.notifier).loadAuto(),
    ),
    step(
      'Calendar',
      () => ref.read(calendarSummaryProvider.notifier).loadAuto(),
    ),
    step(
      'Expenses',
      () => ref.read(expensesSummaryProvider.notifier).loadFromGoogleDrive(),
    ),
  ]);

  await ref.read(homeLastRefreshProvider.notifier).mark();
  return failed;
}
