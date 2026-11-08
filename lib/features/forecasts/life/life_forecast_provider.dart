import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/calendar/data/calendar_service.dart';
import 'package:personal/features/expenses/data/expenses_service.dart';
import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/forecasts/life/life_forecasts.dart';
import 'package:personal/features/forecasts/prediction_selection_service.dart';
import 'package:personal/features/game_activity/game_activity_service.dart';
import 'package:personal/features/health/data/health_service.dart';
import 'package:personal/features/health/data/health_summary.dart';
import 'package:personal/features/location/analysis/work_arrival_stats.dart';
import 'package:personal/features/location/data/location_insights_providers.dart';
import 'package:personal/features/location/data/location_service.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/screen_time/data/screen_time_models.dart';
import 'package:personal/features/screen_time/data/screen_time_service.dart';

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
    dailySpend: spend,
    fitnessGoal: config?.fitnessGoal ?? '',
    ledger: ledger.transactions,
    spending: history.transactions,
    activities: location.activities,
    placeVisits: location.placeVisits,
    placeNames: ref.watch(placeNamesProvider),
    currency: history.currency,
    weekendDays: config?.weekendDays ?? const [],
    screen:
        ref.watch(screenTimeRecentProvider).valueOrNull ??
        ScreenTimeSummary.empty,
  );
});

/// Forecasts for sleep, body, routine and habits, ready for the dashboard.
final lifeForecastsProvider = Provider<List<LifeForecast>>(
  (ref) => computeLifeForecasts(
    ref.watch(lifeInputsProvider),
    disabled: ref.watch(predictionDisabledProvider),
  ),
);
