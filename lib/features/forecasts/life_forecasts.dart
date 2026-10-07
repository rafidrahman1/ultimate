import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_patterns.dart';
import 'package:personal/features/forecasts/life_forecasts_body.dart';
import 'package:personal/features/forecasts/life_forecasts_body_more.dart';
import 'package:personal/features/forecasts/life_forecasts_combined.dart';
import 'package:personal/features/forecasts/life_forecasts_money.dart';
import 'package:personal/features/forecasts/life_forecasts_move.dart';
import 'package:personal/features/forecasts/life_forecasts_routine.dart';

/// Every life forecast the data supports, except those in [disabled] (kind
/// names). Each is skipped, not guessed, when its source has too little
/// history.
List<LifeForecast> computeLifeForecasts(
  LifeInputs i, {
  Set<String> disabled = const {},
}) {
  final builders = <LifeForecastKind, LifeForecast? Function(LifeInputs)>{
    LifeForecastKind.sleep: forecastSleep,
    LifeForecastKind.wakeTime: forecastWakeTime,
    LifeForecastKind.weight: forecastWeight,
    LifeForecastKind.activity: forecastActivity,
    LifeForecastKind.workouts: forecastWorkouts,
    LifeForecastKind.heartRate: forecastHeartRate,
    LifeForecastKind.recovery: forecastRecovery,
    LifeForecastKind.categories: forecastCategories,
    LifeForecastKind.netMonth: forecastNetMonth,
    LifeForecastKind.billAlerts: forecastBillAlerts,
    LifeForecastKind.fuelPrice: forecastFuelPrice,
    LifeForecastKind.holidaySpend: forecastHolidaySpend,
    LifeForecastKind.workArrival: forecastWorkArrival,
    LifeForecastKind.commute: forecastCommute,
    LifeForecastKind.officeDay: forecastOfficeDay,
    LifeForecastKind.weeklyKm: forecastWeeklyKm,
    LifeForecastKind.revisit: forecastRevisit,
    LifeForecastKind.calendarLoad: forecastCalendarLoad,
    LifeForecastKind.freeTime: forecastFreeTime,
    LifeForecastKind.gaming: forecastGaming,
    LifeForecastKind.checklist: forecastChecklist,
    LifeForecastKind.checklistThemes: forecastChecklistThemes,
    LifeForecastKind.patterns: forecastPatterns,
    LifeForecastKind.sleepSpend: forecastSleepSpend,
    LifeForecastKind.bestDay: forecastBestDay,
    LifeForecastKind.burnout: forecastBurnout,
  };
  return [
    for (final e in builders.entries)
      if (!disabled.contains(e.key.name)) ?e.value(i),
  ];
}
