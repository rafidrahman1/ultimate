import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecasts_body.dart';
import 'package:personal/features/forecasts/life/life_forecasts_commute.dart';
import 'package:personal/features/forecasts/life/life_forecasts_money.dart';
import 'package:personal/features/forecasts/life/life_forecasts_planning.dart';

/// Every life forecast the data supports, except those in [disabled] (kind
/// names). Each is skipped, not guessed, when its source has too little
/// history.
List<LifeForecast> computeLifeForecasts(
  LifeInputs i, {
  Set<String> disabled = const {},
}) {
  final builders = <LifeForecastKind, LifeForecast? Function(LifeInputs)>{
    LifeForecastKind.weight: forecastWeight,
    LifeForecastKind.activity: forecastActivity,
    LifeForecastKind.workouts: forecastWorkouts,
    LifeForecastKind.heartRate: forecastHeartRate,
    LifeForecastKind.recovery: forecastRecovery,
    LifeForecastKind.billAlerts: forecastBillAlerts,
    LifeForecastKind.holidaySpend: forecastHolidaySpend,
    LifeForecastKind.commute: forecastCommute,
    LifeForecastKind.checklistThemes: forecastChecklistThemes,
    LifeForecastKind.bestDay: forecastBestDay,
  };
  return [
    for (final e in builders.entries)
      if (!disabled.contains(e.key.name)) ?e.value(i),
  ];
}
