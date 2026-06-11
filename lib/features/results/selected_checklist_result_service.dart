import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/features/analysis/month_end_analysis_notification_service.dart';
import 'package:personal/features/results/insights_parser.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/core/app_log.dart';

const _homeChecklistResultIdKey = 'home_checklist_result_id_v1';

/// Analysis result whose checklist opens from the Home app bar.
final selectedChecklistResultIdProvider =
    NotifierProvider<SelectedChecklistResultNotifier, String?>(
      SelectedChecklistResultNotifier.new,
    );

class SelectedChecklistResultNotifier extends Notifier<String?> {
  static String? _memoryFallback;

  @override
  String? build() {
    unawaited(_hydrateFromPrefs());
    return _memoryFallback;
  }

  Future<void> _hydrateFromPrefs() async {
    final prefs = await _safePrefs();
    if (prefs == null) return;

    final loaded = prefs.getString(_homeChecklistResultIdKey);
    if (loaded == state) return;

    _memoryFallback = loaded;
    state = loaded;
  }

  Future<void> select(String resultId) async {
    if (resultId.isEmpty) return;
    _memoryFallback = resultId;
    state = resultId;

    final prefs = await _safePrefs();
    await prefs?.setString(_homeChecklistResultIdKey, resultId);
    await MonthEndAnalysisNotificationService.scheduleFromSettings();
  }

  Future<void> clear() async {
    _memoryFallback = null;
    state = null;

    final prefs = await _safePrefs();
    await prefs?.remove(_homeChecklistResultIdKey);
    await MonthEndAnalysisNotificationService.scheduleFromSettings();
  }

  Future<void> onResultDeleted(String resultId) async {
    if (state != resultId) return;
    await clear();
  }

  Future<SharedPreferences?> _safePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on PlatformException catch (error) {
      AppLog.warn('SharedPreferences channel error: $error');
      return null;
    } catch (error) {
      AppLog.warn('SharedPreferences init failed: $error');
      return null;
    }
  }
}

List<AnalysisResult> analysisResultsWithChecklist(
  List<AnalysisResult> results,
) {
  return results
      .where((r) => InsightsReportParser.parse(r.output).actions.isNotEmpty)
      .toList();
}

/// Picks [storedId] when still valid, otherwise the newest report with a checklist.
String? resolveSelectedChecklistResultId({
  required List<AnalysisResult> withChecklist,
  String? storedId,
}) {
  if (withChecklist.isEmpty) return null;
  if (storedId != null && withChecklist.any((r) => r.id == storedId)) {
    return storedId;
  }
  return withChecklist.first.id;
}
