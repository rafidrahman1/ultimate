import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal/core/period/analysis_period.dart';
import 'package:personal/features/bike/data/odometer_service.dart';
import 'package:personal/features/calendar/data/calendar_service.dart';
import 'package:personal/features/calendar/data/day_off.dart';
import 'package:personal/features/expenses/analysis/expense_insights.dart';
import 'package:personal/features/expenses/data/expenses_service.dart';
import 'package:personal/features/forecasts/fuel/fuel_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_provider.dart';
import 'package:personal/features/forecasts/outlook/outlook_forecast.dart';
import 'package:personal/features/forecasts/outlook/recurring_forecast.dart';
import 'package:personal/features/forecasts/prediction_selection_service.dart';
import 'package:personal/features/location/data/location_insights_providers.dart';
import 'package:personal/features/location/data/location_service.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';

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
    this.odometer,
    this.life = const [],
    this.currency = '',
    this.spendSeries = const [],
  });

  final FuelForecast? fuel;
  final List<UpcomingCharge> upcomingCharges;

  /// This month's spending pace. Context for the budget estimate, not a
  /// prediction of its own.
  final MonthProjection? monthPace;
  final BudgetOutlook? budget;
  final PaydayOutlook? payday;
  final BikeServiceForecast? bikeService;
  final BikeServiceForecast? bikeOil;

  /// Bike odometer readings; null when the prediction is switched off.
  final OdometerLog? odometer;

  /// Sleep, body, routine and habit forecasts.
  final List<LifeForecast> life;
  final String currency;

  /// Running total of real spending for each day of the current month so far,
  /// then the projected month total as the last point. Empty when there is no
  /// projection.
  final List<double> spendSeries;

  bool get isEmpty =>
      fuel == null &&
      upcomingCharges.isEmpty &&
      budget == null &&
      payday == null &&
      bikeService == null &&
      bikeOil == null &&
      odometer == null &&
      life.isEmpty;
}

final predictionsProvider = Provider<Predictions>((ref) {
  // Always the real current month, whatever month is selected.
  final period = AnalysisPeriod.forDataMonth(clock.now());
  final raw = ref.watch(expensesSummaryProvider);
  final forSpending = ref
      .watch(expensesHistoryProvider)
      .forAnalysisPeriod(period);
  final location = ref.watch(locationSummaryProvider);
  final activities = location.activities;
  final placeVisits = location.placeVisits;
  final placeNames = ref.watch(placeNamesProvider);
  final odometer = ref.watch(odometerLogProvider);
  final weekendDays =
      ref.watch(promptConfigProvider).value?.weekendDays ?? const <int>[];
  final holidays = holidayDaysOf(ref.watch(calendarSummaryProvider).events);
  final off = ref.watch(predictionDisabledProvider);
  bool on(String key) => !off.contains(key);

  final now = clock.now();
  final upcoming = forecastRecurringCharges(raw.transactions, now: now);
  final projection = computeExpenseInsights(
    forSpending,
    now: now,
    periodStart: period.dataMonthStart,
  ).projection;
  final budget = double.tryParse(
    (ref.watch(promptConfigProvider).value?.monthlyBudgetBdt ?? '')
        .replaceAll(',', '')
        .trim(),
  );

  final spendSeries = <double>[];
  if (projection != null) {
    final days = now.day;
    final perDay = List<double>.filled(days, 0);
    for (final t in forSpending.transactions) {
      if (!t.isRealExpense) continue;
      final d = t.date.toLocal();
      if (d.year == now.year && d.month == now.month && d.day <= days) {
        perDay[d.day - 1] += t.amount.abs();
      }
    }
    var running = 0.0;
    for (final v in perDay) {
      spendSeries.add(running += v);
    }
    spendSeries.add(projection.projected);
  }

  // Fuel, bills, income and service read the whole export, ignoring category
  // exclusions: fuel can be left out of spending and still be worth forecasting.
  return Predictions(
    fuel: on('fuel')
        ? forecastNextFuelPurchase(
            raw.transactions,
            activities: activities,
            odometer: odometer,
            weekendDays: weekendDays,
            holidays: holidays,
            placeVisits: placeVisits,
            placeNames: placeNames,
            now: now,
          )
        : null,
    upcomingCharges: on('bills') ? upcoming : const [],
    monthPace: projection,
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
        ? forecastBikeService(
            raw.transactions,
            activities,
            now: now,
            odometer: odometer,
          )
        : null,
    bikeOil: on('oil')
        ? forecastBikeOilChange(
            raw.transactions,
            activities,
            now: now,
            odometer: odometer,
          )
        : null,
    odometer: on('odometer') ? odometer : null,
    life: ref.watch(lifeForecastsProvider),
    currency: forSpending.currency,
    spendSeries: spendSeries,
  );
});
