import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';
import 'package:personal/features/forecasts/life_raw_data.dart';

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
