import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/expenses/expense_insights.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/features/expenses/fuel_forecast.dart';
import 'package:personal/features/expenses/outlook_forecast.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/expenses/recurring_forecast.dart';
import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_provider.dart';
import 'package:personal/features/forecasts/prediction_selection_service.dart';
import 'package:personal/features/location/location_service.dart';

/// Everything the app predicts, in one place for the dashboard.
class Predictions {
  const Predictions({
    this.fuel,
    this.upcomingCharges = const [],
    this.monthPace,
    this.budget,
    this.payday,
    this.bikeService,
    this.bikeOil,
    this.life = const [],
    this.currency = '',
  });

  final FuelForecast? fuel;
  final List<UpcomingCharge> upcomingCharges;
  final MonthProjection? monthPace;
  final BudgetOutlook? budget;
  final PaydayOutlook? payday;
  final BikeServiceForecast? bikeService;
  final BikeServiceForecast? bikeOil;

  /// Sleep, body, routine and habit forecasts.
  final List<LifeForecast> life;
  final String currency;

  bool get isEmpty =>
      fuel == null &&
      upcomingCharges.isEmpty &&
      monthPace == null &&
      budget == null &&
      payday == null &&
      bikeService == null &&
      bikeOil == null &&
      life.isEmpty;
}

final predictionsProvider = Provider<Predictions>((ref) {
  final period = ref.watch(analysisPeriodProvider);
  final raw = ref.watch(expensesSummaryProvider);
  final forSpending = ref.watch(expensesForAnalysisProvider);
  final activities = ref.watch(locationSummaryProvider).activities;
  final off = ref.watch(predictionDisabledProvider);
  bool on(String key) => !off.contains(key);

  final now = DateTime.now();
  final upcoming = forecastRecurringCharges(raw.transactions, now: now);
  final projection = computeExpenseInsights(
    forSpending,
    now: now,
    periodStart: period.dataMonthStart,
  ).projection;
  final budget = double.tryParse(
    (ref.watch(promptConfigProvider).valueOrNull?.monthlyBudgetBdt ?? '')
        .replaceAll(',', '')
        .trim(),
  );

  // Fuel, bills, income and service read the whole export, ignoring category
  // exclusions: fuel can be left out of spending and still be worth forecasting.
  return Predictions(
    fuel: on('fuel')
        ? forecastNextFuelPurchase(
            raw.transactions,
            activities: activities,
            now: now,
          )
        : null,
    upcomingCharges: on('bills') ? upcoming : const [],
    monthPace: on('month') ? projection : null,
    budget: on('budget')
        ? forecastBudgetRunout(budget: budget, projection: projection, now: now)
        : null,
    payday: on('payday')
        ? forecastPayday(
            raw.transactions,
            projection: projection,
            upcoming: upcoming,
            now: now,
          )
        : null,
    bikeService: on('bike')
        ? forecastBikeService(raw.transactions, activities, now: now)
        : null,
    bikeOil: on('oil')
        ? forecastBikeOilChange(raw.transactions, activities, now: now)
        : null,
    life: ref.watch(lifeForecastsProvider),
    currency: forSpending.currency,
  );
});
