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
  // Next usual training day from tomorrow on.
  var next = i.today;
  for (var g = 1; g <= 7; g++) {
    next = i.today.add(Duration(days: g));
    if (top.isNotEmpty && byDay[next.weekday] == top.first.value) break;
  }
  return LifeForecast(
    kind: LifeForecastKind.workouts,
    headline: '~${perWeek.toStringAsFixed(1)}/week',
    detail:
        'Usually ${usual.join(' & ')} · $soFar this week · next likely ${weekdayShort(next)}',
    date: next,
    notes: [
      '${v.workouts.length} workouts over $spanDays days; ${v.totalWorkoutTime.inMinutes} minutes in total.',
    ],
    signature: fingerprint([v.workouts.length, soFar]),
    rawData: vitalsRows(i),
    question:
        'Predict how many workouts I will do over the next 7 days (today '
        'is ${dateLine.format(i.today)}) and on which days. Count them by '
        'week and weekday from the workout rows, and weigh this week so '
        'far and the calendar. "value" is the workout count for the next '
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
    detail: 'resting HR tomorrow · ${signed(-s)} bpm per extra hour asleep',
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

/// When you wake tomorrow, and whether wake time is drifting.
LifeForecast? forecastWakeTime(LifeInputs i) {
  final nights = i.nights.where((n) => n.session != null).toList();
  if (nights.length < 5) return null;
  final wake = [
    for (final n in nights) minutesOfDay(n.session!.endTime).toDouble(),
  ];
  final tomorrow = i.today.add(const Duration(days: 1));
  final same = [
    for (var k = 0; k < nights.length; k++)
      if (nights[k].wakeDate.weekday == tomorrow.weekday) wake[k],
  ];
  final recent = ewma(wake);
  final expected = same.length >= 2 ? 0.6 * recent + 0.4 * mean(same) : recent;
  final xs = [for (var k = 0; k < wake.length; k++) k.toDouble()];
  final drift = slope(xs, wake) ?? 0;
  return LifeForecast(
    kind: LifeForecastKind.wakeTime,
    headline: '~${clockLabel(expected)}',
    detail:
        '${weekdayShort(tomorrow)} · drifting ${drift >= 0 ? 'later' : 'earlier'} ${drift.abs().toStringAsFixed(0)} min/day',
    date: tomorrow,
    notes: [
      'Recent wake times blended with your ${same.length} past ${weekdayShort(tomorrow)}s.',
    ],
    signature: fingerprint([nights.length, expected]),
    rawData: sleepRows(i),
    question:
        'Predict what time I will wake on ${dateLine.format(tomorrow)}: '
        'weigh the weekday habit, recent drift and how late I went to bed '
        'if known. "headline" is the time as HH:mm.',
  );
}
