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

/// Workouts per week and the days you usually train.
LifeForecast? forecastWorkouts(LifeInputs i) {
  final v = i.vitals;
  if (v == null || v.workouts.length < 3) return null;
  final spanDays = v.periodEnd.difference(v.periodStart).inDays + 1;
  final weeks = (spanDays / 7).clamp(1.0, 52.0);
  final perWeek = v.workouts.length / weeks;
  final byDay = <int, int>{};
  for (final w in v.workouts) {
    byDay[w.start.weekday] = (byDay[w.start.weekday] ?? 0) + 1;
  }
  final top = byDay.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final usual = top.take(2).map((e) => weekdayShort(DateTime(2024, 1, e.key)));
  final monday = i.today.subtract(Duration(days: i.today.weekday - 1));
  final soFar = v.workouts
      .where((w) => !dayOf(w.start).isBefore(monday))
      .length;
  // Next likely training day from tomorrow on. Workouts are counted per day
  // type (workday or day off, the latter covering weekends and holidays) and
  // weekday, as a rate over the days of that kind in the period, so a holiday
  // Wednesday is judged as a day off rather than as an ordinary Wednesday.
  final holidays = holidayDays(i);
  bool off(DateTime d) => isDayOff(i, d, holidays);
  final start = dayOf(v.periodStart);
  final spanDaysList = [
    for (var k = 0; k < spanDays; k++) start.add(Duration(days: k)),
  ];
  final daysOf = <int, int>{};
  final doneOf = <int, int>{};
  int key(DateTime d) => (off(d) ? 8 : 0) + d.weekday;
  for (final d in spanDaysList) {
    daysOf.update(key(d), (n) => n + 1, ifAbsent: () => 1);
  }
  for (final w in v.workouts) {
    doneOf.update(key(dayOf(w.start)), (n) => n + 1, ifAbsent: () => 1);
  }
  double rate(DateTime d) {
    final own = key(d);
    if ((daysOf[own] ?? 0) >= 3) return (doneOf[own] ?? 0) / daysOf[own]!;
    final base = off(d) ? 8 : 0;
    var days = 0;
    var done = 0;
    for (var w = 1; w <= 7; w++) {
      days += daysOf[base + w] ?? 0;
      done += doneOf[base + w] ?? 0;
    }
    return days == 0 ? 0 : done / days;
  }

  var next = i.today.add(const Duration(days: 1));
  var bestRate = -1.0;
  for (var g = 1; g <= 7; g++) {
    final d = i.today.add(Duration(days: g));
    final r = rate(d);
    if (r > bestRate) {
      bestRate = r;
      next = d;
    }
  }
  final nextKind = holidays.contains(next)
      ? ' (a holiday)'
      : off(next)
      ? ' (a day off)'
      : '';
  return LifeForecast(
    kind: LifeForecastKind.workouts,
    headline: '~${perWeek.toStringAsFixed(1)}/week',
    detail:
        'You usually train on ${usual.join(' and ')}. '
        '${soFar == 0 ? 'No workouts yet this week' : '$soFar so far this week'}, '
        'next one likely ${weekdayShort(next)}$nextKind.',
    date: next,
    notes: [
      '${v.workouts.length} workouts over $spanDays days; ${v.totalWorkoutTime.inMinutes} minutes in total.',
    ],
    signature: fingerprint([v.workouts.length, soFar]),
    rawData: vitalsRows(i),
    question:
        'Predict how many workouts I will do over the next 7 days (today '
        'is ${dateLine.format(i.today)}) and on which days. Count them by '
        'week and weekday from the workout rows, treating weekends and public '
        'holidays as days off and judging them separately from workdays, '
        'and weigh this week so far and the calendar. "value" is the workout count for the next '
        '7 days and "date" the most likely next workout.',
  );
}

/// How sleep moves resting heart rate, and what that means for tomorrow.
LifeForecast? forecastRecovery(LifeInputs i) {
  final v = i.vitals;
  if (v == null) return null;
  final sleep = {
    for (final n in i.nights)
      if (n.session != null)
        dayOf(n.wakeDate): n.session!.duration.inMinutes / 60,
  };
  final xs = <double>[];
  final ys = <double>[];
  for (final d in v.days) {
    final h = sleep[dayOf(d.date)];
    if (h == null || d.restingHr == null) continue;
    xs.add(h);
    ys.add(d.restingHr!.toDouble());
  }
  if (xs.length < 10) return null;
  final r = pearson(xs, ys);
  final s = slope(xs, ys);
  if (r == null || s == null || r.abs() < 0.25) return null;
  final hours = [for (final n in i.nights) n.session!.duration.inMinutes / 60];
  final tonight = ewma(hours);
  final expected = mean(ys) + s * (tonight - mean(xs));
  return LifeForecast(
    kind: LifeForecastKind.recovery,
    headline: '~${expected.round()} bpm',
    detail:
        'Your expected resting heart rate tomorrow. Each extra hour of sleep '
        '${s < 0 ? 'lowers' : 'raises'} it by about ${s.abs().toStringAsFixed(1)} bpm.',
    attention: s < 0 && tonight < 6.5,
    notes: [
      'Compared sleep with that day\'s resting heart rate over ${xs.length} days (r = ${r.toStringAsFixed(2)}).',
      'Assumes about ${hoursLabel(tonight)} of sleep tonight.',
    ],
    signature: fingerprint([xs.length, r, expected]),
    rawData: '${vitalsRows(i)}\n\n${sleepRows(i)}',
    question:
        'Work out how my sleep affects resting heart rate and HRV the next '
        'day, from the paired rows, then predict tomorrow\'s resting heart '
        'rate given tonight\'s likely sleep. "value" is bpm.',
  );
}
