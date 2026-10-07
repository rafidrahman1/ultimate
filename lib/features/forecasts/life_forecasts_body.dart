import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';
import 'package:personal/features/forecasts/life_raw_data.dart';

const _sleepTargetHours = 7.5;

/// Tonight's sleep from recent nights and the weekday pattern, plus the sleep
/// debt and where bedtime is drifting.
LifeForecast? forecastSleep(LifeInputs i) {
  final nights = i.nights.where((n) => n.session != null).toList();
  if (nights.length < 5) return null;
  final hours = [for (final n in nights) n.session!.duration.inMinutes / 60];
  final wakeTomorrow = i.today.add(const Duration(days: 1));
  final sameWeekday = [
    for (var k = 0; k < nights.length; k++)
      if (nights[k].wakeDate.weekday == wakeTomorrow.weekday) hours[k],
  ];
  final recent = ewma(hours);
  final expected = sameWeekday.length >= 2
      ? 0.6 * recent + 0.4 * mean(sameWeekday)
      : recent;

  final last7 = hours.length > 7 ? hours.sublist(hours.length - 7) : hours;
  final debt = last7.fold<double>(0, (a, h) => a + (_sleepTargetHours - h));

  // Bedtime as minutes after noon so 23:30 and 00:30 sit one hour apart.
  final bed = [
    for (final n in nights) (minutesOfDay(n.session!.startTime) + 720) % 1440.0,
  ];
  final xs = [for (var k = 0; k < bed.length; k++) k.toDouble()];
  final drift = slope(xs, bed) ?? 0;
  final recentBed = mean(bed.length > 7 ? bed.sublist(bed.length - 7) : bed);
  final bedTonight = recentBed + drift * 2;

  final lowSleep = expected < 6.5;
  return LifeForecast(
    kind: LifeForecastKind.sleep,
    headline: '~${hoursLabel(expected)}',
    detail:
        'Bed ~${clockLabel(bedTonight + 720)} · '
        '${debt >= 1
            ? '${debt.toStringAsFixed(1)} h debt this week'
            : debt <= -1
            ? '${(-debt).toStringAsFixed(1)} h ahead this week'
            : 'on target this week'}',
    attention: lowSleep,
    notes: [
      'Weighted recent average ${hoursLabel(recent)}'
          '${sameWeekday.length >= 2 ? ', blended with your ${sameWeekday.length} past ${_weekday(wakeTomorrow)}s (${hoursLabel(mean(sameWeekday))})' : ''}.',
      'Sleep debt is measured against $_sleepTargetHours h a night over the last ${last7.length} nights.',
      'Bedtime is moving ${drift >= 0 ? 'later' : 'earlier'} by '
          '${drift.abs().toStringAsFixed(0)} min a day.',
    ],
    signature: fingerprint([nights.length, nights.last.wakeDate, expected]),
    rawData: sleepRows(i),
    question:
        'Predict how long I will sleep tonight (the night ending '
        '${dateLine.format(wakeTomorrow)}) and my bedtime. Use the nightly '
        'rows: weigh recent nights, weekday patterns, stage quality, and any '
        'drift in bedtime. "value" is hours of sleep; "detail" gives expected '
        'bedtime and sleep debt against a ${_sleepTargetHours}h target.',
  );
}

String _weekday(DateTime d) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];

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
        'in 30 days · ${steady ? 'holding steady' : '${signed(perWeek)} kg/week'} '
        '· now ${now.toStringAsFixed(1)}',
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
        'Next 7 days ≈ ${(daily * 7 / 1000).round()}k steps'
        '${v.workouts.isEmpty ? '' : ' · ~${perWeekWorkouts.round()} workouts'}',
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
        'in 14 days · ${signed(perDay * 7)} bpm/week'
        '${hrv == null ? '' : ' · HRV ~${hrv.round()} ms'}',
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
