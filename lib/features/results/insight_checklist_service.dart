import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/analysis_period.dart';

const _prefix = 'insight_checklist_v1_';

final insightChecklistProvider =
    AsyncNotifierProvider.family<InsightChecklistNotifier, Set<int>, String>(
  InsightChecklistNotifier.new,
);

class InsightChecklistNotifier extends FamilyAsyncNotifier<Set<int>, String> {
  late String _storageKey;

  @override
  Future<Set<int>> build(String storageKey) async {
    _storageKey = storageKey;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$storageKey');
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => (e as num).toInt()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> toggle(int index) async {
    final current = state.valueOrNull ?? await future;
    final next = Set<int>.from(current);
    if (next.contains(index)) {
      next.remove(index);
    } else {
      next.add(index);
    }
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$_storageKey',
      jsonEncode(next.toList()..sort()),
    );
  }
}

/// Persists checklist completion per analysis result and week index.
String insightChecklistStorageKey(String resultId, int weekIndex) =>
    '${resultId}_w$weekIndex';

/// Removes saved checklist progress for every week of [resultId].
Future<void> deleteChecklistDataForResult(String resultId) async {
  final prefs = await SharedPreferences.getInstance();
  final keyPrefix = '$_prefix$resultId';
  for (final key in prefs.getKeys()) {
    if (key.startsWith(keyPrefix)) {
      await prefs.remove(key);
    }
  }
}

/// Picks the checklist week that contains [today], or the first / last week
/// in [period]'s checklist month.
int resolveDefaultChecklistWeekIndex({
  required AnalysisPeriod period,
  required int weekCount,
  DateTime? today,
}) {
  if (weekCount <= 0) return 0;
  final local = (today ?? DateTime.now()).toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final monthStart = DateTime(
    period.checklistMonthStart.year,
    period.checklistMonthStart.month,
    period.checklistMonthStart.day,
  );

  for (var i = 0; i < period.checklistWeeks.length && i < weekCount; i++) {
    final week = period.checklistWeeks[i];
    final start = DateTime(week.start.year, week.start.month, week.start.day);
    final end = DateTime(week.end.year, week.end.month, week.end.day);
    if (!day.isBefore(start) && !day.isAfter(end)) return i;
  }

  if (day.isBefore(monthStart)) return 0;
  return weekCount - 1;
}
