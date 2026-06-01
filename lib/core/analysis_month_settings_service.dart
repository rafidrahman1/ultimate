import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analysis_period.dart';

const _analysisMonthYearKey = 'analysis_month_year_v1';
const _analysisMonthMonthKey = 'analysis_month_month_v1';

/// First day of the calendar month used for health, expenses, location, and game activity.
final selectedAnalysisMonthProvider =
    NotifierProvider<SelectedAnalysisMonthNotifier, DateTime>(
  SelectedAnalysisMonthNotifier.new,
);

/// Derived analysis window: full [selectedAnalysisMonthProvider] plus the following checklist month.
final analysisPeriodProvider = Provider<AnalysisPeriod>((ref) {
  final monthStart = ref.watch(selectedAnalysisMonthProvider);
  return AnalysisPeriod.forDataMonth(monthStart);
});

class SelectedAnalysisMonthNotifier extends Notifier<DateTime> {
  static DateTime _memoryFallback = _currentMonthStart();

  @override
  DateTime build() {
    unawaited(_hydrateFromPrefs());
    return _memoryFallback;
  }

  static DateTime _currentMonthStart() {
    final now = DateTime.now().toLocal();
    return DateTime(now.year, now.month, 1);
  }

  Future<void> _hydrateFromPrefs() async {
    final prefs = await _safePrefs();
    if (prefs == null) return;

    final year = prefs.getInt(_analysisMonthYearKey);
    final month = prefs.getInt(_analysisMonthMonthKey);
    if (year == null || month == null) return;

    final loaded = DateTime(year, month, 1);
    if (loaded.year == state.year && loaded.month == state.month) return;

    _memoryFallback = loaded;
    state = loaded;
  }

  Future<void> setMonth(DateTime monthStart) async {
    final local = monthStart.toLocal();
    final normalized = DateTime(local.year, local.month, 1);
    if (normalized.year == state.year && normalized.month == state.month) {
      return;
    }

    _memoryFallback = normalized;
    state = normalized;

    final prefs = await _safePrefs();
    if (prefs != null) {
      await Future.wait<bool>([
        prefs.setInt(_analysisMonthYearKey, normalized.year),
        prefs.setInt(_analysisMonthMonthKey, normalized.month),
      ]);
    }
  }

  Future<SharedPreferences?> _safePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on PlatformException catch (error) {
      debugPrint('SharedPreferences channel error: $error');
      return null;
    } catch (error) {
      debugPrint('SharedPreferences init failed: $error');
      return null;
    }
  }
}
