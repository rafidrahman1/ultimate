import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/features/analysis/month_end_analysis_notification_service.dart';
import 'package:personal/features/analysis/analysis_period.dart';

const _prefixV1 = 'insight_checklist_v1_';
const _prefixV2 = 'insight_checklist_v2_';

enum ChecklistItemStatus { pending, completed, failed }

/// Per-week checklist progress with completed and failed item indices.
class WeekChecklistState {
  const WeekChecklistState({
    this.completed = const {},
    this.failed = const {},
  });

  final Set<int> completed;
  final Set<int> failed;

  static const empty = WeekChecklistState();

  ChecklistItemStatus statusFor(int index) {
    if (completed.contains(index)) return ChecklistItemStatus.completed;
    if (failed.contains(index)) return ChecklistItemStatus.failed;
    return ChecklistItemStatus.pending;
  }

  WeekChecklistState withStatus(int index, ChecklistItemStatus status) {
    final nextCompleted = Set<int>.from(completed);
    final nextFailed = Set<int>.from(failed);
    nextCompleted.remove(index);
    nextFailed.remove(index);
    switch (status) {
      case ChecklistItemStatus.pending:
        break;
      case ChecklistItemStatus.completed:
        nextCompleted.add(index);
      case ChecklistItemStatus.failed:
        nextFailed.add(index);
    }
    return WeekChecklistState(completed: nextCompleted, failed: nextFailed);
  }

  WeekChecklistState applyVerification({
    required Set<int> verifiedCompleted,
    required Set<int> verifiedFailed,
  }) {
    final nextCompleted = Set<int>.from(completed);
    final nextFailed = Set<int>.from(failed);

    for (final index in verifiedCompleted) {
      nextFailed.remove(index);
      nextCompleted.add(index);
    }
    for (final index in verifiedFailed) {
      nextCompleted.remove(index);
      nextFailed.add(index);
    }

    return WeekChecklistState(completed: nextCompleted, failed: nextFailed);
  }

  int resolvedCount(Set<int> allIndices) {
    var count = 0;
    for (final index in allIndices) {
      if (completed.contains(index) || failed.contains(index)) count++;
    }
    return count;
  }

  Map<String, dynamic> toJson() => {
        'completed': completed.toList()..sort(),
        'failed': failed.toList()..sort(),
      };

  factory WeekChecklistState.fromJson(Map<String, dynamic> json) {
    Set<int> parseList(String key) {
      final raw = json[key];
      if (raw is! List) return {};
      return raw.map((e) => (e as num).toInt()).toSet();
    }

    return WeekChecklistState(
      completed: parseList('completed'),
      failed: parseList('failed'),
    );
  }
}

final insightChecklistProvider =
    AsyncNotifierProvider.family<InsightChecklistNotifier, WeekChecklistState,
        String>(
  InsightChecklistNotifier.new,
);

class InsightChecklistNotifier
    extends FamilyAsyncNotifier<WeekChecklistState, String> {
  late String _storageKey;

  @override
  Future<WeekChecklistState> build(String storageKey) async {
    _storageKey = storageKey;
    return _loadState(storageKey);
  }

  Future<void> toggle(int index) async {
    final current = state.valueOrNull ?? await future;
    final status = current.statusFor(index);
    final nextStatus = switch (status) {
      ChecklistItemStatus.pending => ChecklistItemStatus.completed,
      ChecklistItemStatus.completed => ChecklistItemStatus.failed,
      ChecklistItemStatus.failed => ChecklistItemStatus.pending,
    };
    final next = current.withStatus(index, nextStatus);
    await _persist(next);
  }

  Future<void> applyVerification({
    required Set<int> completed,
    required Set<int> failed,
  }) async {
    final current = state.valueOrNull ?? await future;
    final next = current.applyVerification(
      verifiedCompleted: completed,
      verifiedFailed: failed,
    );
    await _persist(next);
  }

  Future<void> _persist(WeekChecklistState next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefixV2$_storageKey',
      jsonEncode(next.toJson()),
    );
    await MonthEndAnalysisNotificationService.scheduleFromSettings();
  }
}

Future<WeekChecklistState> _loadState(String storageKey) async {
  final prefs = await SharedPreferences.getInstance();
  final v2Raw = prefs.getString('$_prefixV2$storageKey');
  if (v2Raw != null) {
    try {
      final map = jsonDecode(v2Raw) as Map<String, dynamic>;
      return WeekChecklistState.fromJson(map);
    } catch (_) {
      return WeekChecklistState.empty;
    }
  }

  final v1Raw = prefs.getString('$_prefixV1$storageKey');
  if (v1Raw == null) return WeekChecklistState.empty;
  try {
    final list = jsonDecode(v1Raw) as List<dynamic>;
    final completed = list.map((e) => (e as num).toInt()).toSet();
    return WeekChecklistState(completed: completed);
  } catch (_) {
    return WeekChecklistState.empty;
  }
}

/// Persists checklist completion per analysis result and week index.
String insightChecklistStorageKey(String resultId, int weekIndex) =>
    '${resultId}_w$weekIndex';

/// Removes saved checklist progress for every week of [resultId].
Future<void> deleteChecklistDataForResult(String resultId) async {
  final prefs = await SharedPreferences.getInstance();
  for (final prefix in [_prefixV1, _prefixV2]) {
    final keyPrefix = '$prefix$resultId';
    for (final key in prefs.getKeys()) {
      if (key.startsWith(keyPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}

/// Completed and failed indices per week for [resultId].
class ChecklistCompletionByWeek {
  const ChecklistCompletionByWeek({
    required this.completedByWeek,
    required this.failedByWeek,
  });

  final Map<int, Set<int>> completedByWeek;
  final Map<int, Set<int>> failedByWeek;

  WeekChecklistState stateForWeek(int weekIndex) => WeekChecklistState(
        completed: completedByWeek[weekIndex] ?? {},
        failed: failedByWeek[weekIndex] ?? {},
      );
}

/// Loads persisted checklist state for every week of [resultId].
Future<ChecklistCompletionByWeek> loadChecklistCompletionForResult(
  String resultId,
  int weekCount,
) async {
  final completedByWeek = <int, Set<int>>{};
  final failedByWeek = <int, Set<int>>{};

  for (var weekIndex = 0; weekIndex < weekCount; weekIndex++) {
    final storageKey = insightChecklistStorageKey(resultId, weekIndex);
    final state = await _loadState(storageKey);
    completedByWeek[weekIndex] = state.completed;
    failedByWeek[weekIndex] = state.failed;
  }

  return ChecklistCompletionByWeek(
    completedByWeek: completedByWeek,
    failedByWeek: failedByWeek,
  );
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
