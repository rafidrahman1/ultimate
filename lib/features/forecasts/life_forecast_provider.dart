import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/analysis_result_period.dart';
import 'package:personal/features/calendar/calendar_service.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';
import 'package:personal/features/forecasts/life_forecasts.dart';
import 'package:personal/features/forecasts/prediction_selection_service.dart';
import 'package:personal/features/location/location_insights_providers.dart';
import 'package:personal/features/game_activity/game_activity_service.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/location/location_service.dart';
import 'package:personal/features/location/work_arrival_stats.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/results/insight_checklist_service.dart';
import 'package:personal/features/results/insights_models.dart';
import 'package:personal/features/results/insights_parser.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/features/results/selected_checklist_result_service.dart';

/// How far the active checklist has got, week by week. Reloaded whenever the
/// dashboard is opened again, since ticking items does not touch a provider.
final checklistProgressProvider =
    FutureProvider.autoDispose<ChecklistProgress?>((ref) async {
      final results =
          ref.watch(analysisResultsProvider).valueOrNull ?? const [];
      final withChecklist = analysisResultsWithChecklist(results);
      final id = resolveSelectedChecklistResultId(
        withChecklist: withChecklist,
        storedId: ref.watch(selectedChecklistResultIdProvider),
      );
      if (id == null) return null;
      final result = withChecklist.firstWhere((r) => r.id == id);
      final parsed = InsightsReportParser.parse(result.output);
      final count = parsed.checklistWeekCount;
      final segments = result.analysisPeriod.checklistWeeks;
      final completion = await loadChecklistCompletionForResult(id, count);
      return ChecklistProgress(
        title: result.title,
        weeks: [
          for (var w = 0; w < count && w < segments.length; w++)
            _weekProgress(parsed, completion, segments[w], w),
        ],
      );
    });

ChecklistWeekProgress _weekProgress(
  InsightsParsedReport parsed,
  ChecklistCompletionByWeek completion,
  ChecklistWeekSegment segment,
  int index,
) {
  final actions = parsed.actionsForWeekIndex(index);
  final doneIdx = completion.completedByWeek[index] ?? const <int>{};
  final byCategory = <String, ({int total, int done})>{};
  for (var a = 0; a < actions.length; a++) {
    final c = actions[a].category;
    final cur = byCategory[c] ?? (total: 0, done: 0);
    byCategory[c] = (
      total: cur.total + 1,
      done: cur.done + (doneIdx.contains(a) ? 1 : 0),
    );
  }
  return ChecklistWeekProgress(
    weekNumber: segment.weekNumber,
    start: segment.start,
    end: segment.end,
    total: actions.length,
    done: doneIdx.length,
    failed: completion.failedByWeek[index]?.length ?? 0,
    byCategory: byCategory,
  );
}

/// The data every life forecast reads.
final lifeInputsProvider = Provider<LifeInputs>((ref) {
  final now = DateTime.now();
  final fetch = ref.watch(monthlyHealthDataProvider).valueOrNull;
  final summary = fetch != null && fetch.hasData
      ? MonthlyHealthSummary.fromFetch(fetch)
      : null;
  final config = ref.watch(promptConfigProvider).valueOrNull;
  final location = ref.watch(locationSummaryProvider);

  final history = ref.watch(expensesHistoryProvider);
  final ledger = ref.watch(expensesSummaryProvider);
  final spend = <DateTime, double>{};
  final since = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 75));
  for (final t in history.transactions) {
    if (!t.isRealExpense) continue;
    final d = dayOf(t.date);
    if (d.isBefore(since)) continue;
    spend[d] = (spend[d] ?? 0) + t.amount.abs();
  }

  return LifeInputs(
    now: now,
    nights: [...?summary?.dailySleep.where((d) => d.hasData)]
      ..sort((a, b) => a.wakeDate.compareTo(b.wakeDate)),
    vitals: summary?.vitals,
    work: location.placeVisits.isEmpty
        ? WorkArrivalStats.empty
        : WorkArrivalStats.analyze(
            placeVisits: location.placeVisits,
            workAddress: config?.workAddress ?? '',
            workHours: config?.workHours ?? '',
          ),
    events: ref.watch(calendarSummaryProvider).events,
    games: ref.watch(gameActivitySummaryProvider).sessions,
    checklist: ref.watch(checklistProgressProvider).valueOrNull,
    dailySpend: spend,
    fitnessGoal: config?.fitnessGoal ?? '',
    ledger: ledger.transactions,
    spending: history.transactions,
    activities: location.activities,
    placeVisits: location.placeVisits,
    placeNames: ref.watch(placeNamesProvider),
    currency: history.currency,
  );
});

/// Forecasts for sleep, body, routine and habits, ready for the dashboard.
final lifeForecastsProvider = Provider<List<LifeForecast>>(
  (ref) => computeLifeForecasts(
    ref.watch(lifeInputsProvider),
    disabled: ref.watch(predictionDisabledProvider),
  ),
);
