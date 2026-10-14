import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/forecasts/life/life_raw_data.dart';

/// Where body weight is heading, from a straight-line fit of the readings.
LifeForecast? forecastWeight(LifeInputs i) {
  final weights = [...?i.vitals?.weights]
    ..sort((a, b) => a.time.compareTo(b.time));
  if (weights.length < 3) return null;
  final first = weights.first.time;
  final span = weights.last.time.difference(first).inDays;
  if (span < 5) return null;
  final xs = [for (final w in weights) w.time.difference(first).inHours / 24.0];
  final ys = [for (final w in weights) w.kg];
  final perDay = slope(xs, ys);
  if (perDay == null) return null;
  final now = weights.last.kg;
  final in30 = now + perDay * 30;
  final perWeek = perDay * 7;
  final steady = perWeek.abs() < 0.1;
  return LifeForecast(
    kind: LifeForecastKind.weight,
    headline: '${in30.toStringAsFixed(1)} kg',
    detail:
        'Your weight in 30 days, from ${now.toStringAsFixed(1)} kg now. '
        '${steady
            ? 'It has been holding steady.'
            : perWeek > 0
            ? 'It has been climbing about ${perWeek.toStringAsFixed(1)} kg a week.'
            : 'It has been dropping about ${(-perWeek).toStringAsFixed(1)} kg a week.'}',
    notes: [
      'Straight-line fit through ${weights.length} readings over $span days.',
      if (i.fitnessGoal.trim().isNotEmpty) 'Your goal: ${i.fitnessGoal.trim()}',
    ],
    signature: fingerprint([weights.length, weights.last.time, now]),
    rawData:
        '${weightRows(i)}\n\nActivity that could explain it:\n${vitalsRows(i)}',
    question:
        'Predict my weight 30 days from today and the date I would reach any '
        'weight goal mentioned here: "${i.fitnessGoal.trim().isEmpty ? 'none stated' : i.fitnessGoal.trim()}". '
        'Fit the readings yourself, allowing for day-to-day noise and for my '
        'recent steps and workouts. "value" is kg in 30 days.',
  );
}

/// Steps and workouts expected over the next seven days.
LifeForecast? forecastActivity(LifeInputs i) {
  final v = i.vitals;
  if (v == null) return null;
  final days = v.stepDays;
  if (days.length < 5) return null;
  final steps = [for (final d in days) d.steps!.toDouble()];
  final recent = steps.length > 7 ? steps.sublist(steps.length - 7) : steps;
  final xs = [for (var k = 0; k < steps.length; k++) k.toDouble()];
  final trend = slope(xs, steps) ?? 0;
  final daily = 0.7 * mean(recent) + 0.3 * ewma(steps);

  final spanDays = v.periodEnd.difference(v.periodStart).inDays + 1;
  final weeks = spanDays / 7;
  final perWeekWorkouts = weeks >= 1 ? v.workouts.length / weeks : 0.0;
  final k = (daily / 1000);
  return LifeForecast(
    kind: LifeForecastKind.activity,
    headline: '~${k.toStringAsFixed(1)}k steps/day',
    detail:
        'About ${(daily * 7 / 1000).round()}k steps over the next week'
        '${v.workouts.isEmpty ? '' : ' and around ${perWeekWorkouts.round()} workout${perWeekWorkouts.round() == 1 ? '' : 's'}'}.',
    notes: [
      'Mean of the last ${recent.length} days blended with a weighted average of all ${steps.length} days.',
      'Trend ${signed(trend * 7, digits: 0)} steps/day per week.',
      if (v.workouts.isNotEmpty)
        '${v.workouts.length} workouts over $spanDays days.',
    ],
    signature: fingerprint([steps.length, daily, v.workouts.length]),
    rawData: vitalsRows(i),
    question:
        'Predict my total steps and number of workouts for the next 7 days '
        '(starting ${dateLine.format(i.today)}), and the daily step average I '
        'will finish this month on. Use the daily rows and workouts, weekday '
        'habits, and my calendar load if given. "value" is steps per day '
        'over the next 7 days.',
  );
}

/// Resting heart rate a couple of weeks out.
LifeForecast? forecastHeartRate(LifeInputs i) {
  final v = i.vitals;
  if (v == null) return null;
  final days = v.days.where((d) => d.restingHr != null).toList();
  if (days.length < 5) return null;
  final first = days.first.date;
  final xs = [for (final d in days) d.date.difference(first).inDays.toDouble()];
  final ys = [for (final d in days) d.restingHr!.toDouble()];
  final perDay = slope(xs, ys);
  if (perDay == null) return null;
  final recent = mean(ys.length > 7 ? ys.sublist(ys.length - 7) : ys);
  final in14 = recent + perDay * 14;
  final rising = perDay * 7 >= 1;
  final hrv = v.averageHrv;
  return LifeForecast(
    kind: LifeForecastKind.heartRate,
    headline: '${in14.round()} bpm',
    detail:
        'Your resting heart rate in two weeks, '
        '${rising
            ? 'rising'
            : perDay * 7 <= -1
            ? 'falling'
            : 'staying about level'}'
        '${perDay.abs() * 7 >= 1 ? ' by about ${(perDay.abs() * 7).toStringAsFixed(0)} bpm a week' : ''}'
        '${hrv == null ? '' : '. Heart rate variability averages ${hrv.round()} ms'}.',
    attention: rising,
    notes: [
      'Latest week averages ${recent.toStringAsFixed(0)} bpm; fitted through ${days.length} days.',
      if (rising)
        'A rising resting heart rate often follows poor sleep, illness or strain.',
    ],
    signature: fingerprint([days.length, days.last.date, recent]),
    rawData:
        '${vitalsRows(i)}\n\nSleep, which affects resting HR:\n${sleepRows(i)}',
    question:
        'Predict my resting heart rate 14 days from today, and say whether '
        'the direction is worth attention. Consider sleep, HRV and workload '
        'in the rows. "value" is bpm.',
  );
}
