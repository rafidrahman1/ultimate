import 'package:personal/features/expenses/analysis/ai_ledger_text.dart';
import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/forecasts/life/life_raw_data.dart';
import 'package:personal/features/health/analysis/sleep_metrics.dart';

/// How far behind the sleep target the last week left you, and the bedtime
/// that would make it up while keeping your usual wake time.
LifeForecast? forecastSleepDebt(LifeInputs i) {
  final from = i.today.subtract(const Duration(days: 7));
  final nights = [
    for (final n in i.nights)
      if (n.session != null && !dayOf(n.wakeDate).isBefore(from)) n,
  ];
  if (nights.length < 4) return null;
  final target = sleepTargetDuration.inMinutes / 60;
  final hours = [for (final n in nights) n.session!.duration.inMinutes / 60];
  final avg = mean(hours);
  final debt = hours.fold<double>(0, (a, h) => a + (target - h));
  final wake = median(nights.map((n) => minutesOfDay(n.session!.endTime)));
  // Win back about a third of the debt tonight, never more than an hour.
  final extra = debt <= 0 ? 0.0 : (debt / 3).clamp(0.0, 1.0);
  final need = target + extra;
  final bed = wake - need * 60;
  final short = debt >= 0.5;
  return LifeForecast(
    kind: LifeForecastKind.sleepDebt,
    headline: short ? '${hoursLabel(debt)} short' : 'On target',
    detail:
        'You averaged ${hoursLabel(avg)} over the last ${nights.length} nights '
        'against a ${hoursLabel(target)} target. '
        '${short ? 'To catch up, be in bed by ${clockLabel(bed)} for a ${clockLabel(wake)} wake-up.' : 'Keep going to bed around ${clockLabel(bed)}.'}',
    attention: debt >= 3.5,
    notes: [
      'Sleep debt is the sum of target minus actual hours over ${nights.length} nights.',
      'Bedtime = your median wake time (${clockLabel(wake)}) minus ${hoursLabel(need)}.',
    ],
    signature: fingerprint([nights.length, debt, wake]),
    rawData: sleepRows(i),
    question:
        'Work out how much sleep I am short of a ${hoursLabel(target)} target '
        'over the last 7 nights (today is ${dateLine.format(i.today)}) and '
        'the bedtime that would recover it while keeping my usual wake time. '
        '"value" is hours of sleep debt.',
  );
}

/// How busy the calendar is over the next seven days against a usual week.
LifeForecast? forecastWeekAhead(LifeInputs i) {
  final hours = eventHoursByDay(i);
  final days = [for (var d = 0; d < 7; d++) i.today.add(Duration(days: d))];
  final total = days.fold<double>(0, (a, d) => a + (hours[d] ?? 0));
  if (total <= 0) return null;
  final past = <double>[];
  for (var w = 1; w <= 4; w++) {
    var sum = 0.0;
    for (var d = 0; d < 7; d++) {
      sum += hours[i.today.subtract(Duration(days: w * 7 - d))] ?? 0;
    }
    if (sum > 0) past.add(sum);
  }
  final usual = past.length >= 2 ? mean(past) : null;
  final busiest = days.reduce(
    (a, b) => (hours[a] ?? 0) >= (hours[b] ?? 0) ? a : b,
  );
  final free = days.where((d) => (hours[d] ?? 0) == 0).length;
  final heavy = usual != null && total >= usual * 1.3;
  return LifeForecast(
    kind: LifeForecastKind.weekAhead,
    headline: '${hoursLabel(total)} booked',
    detail:
        'Busiest on ${weekdayShort(busiest)} ${shortDate.format(busiest)} '
        '(${hoursLabel(hours[busiest] ?? 0)}); $free of 7 days are free'
        '${usual == null
            ? ''
            : heavy
            ? ', and it is heavier than your usual ${hoursLabel(usual)}'
            : total <= usual * 0.7
            ? ', and lighter than your usual ${hoursLabel(usual)}'
            : ', about your usual ${hoursLabel(usual)}'}.',
    attention: heavy,
    date: busiest,
    notes: [
      'Adds up timed calendar events from today through ${shortDate.format(days.last)}; all-day events and holidays are not counted.',
      if (usual != null)
        'Compared with the average of ${past.length} earlier weeks that had events.',
    ],
    signature: fingerprint([total, busiest, free]),
    rawData: calendarRows(i),
    question:
        'Summarise how busy my next 7 days are from ${dateLine.format(i.today)} '
        'using these calendar events, compare with earlier weeks if they are '
        'listed, and name the heaviest day. "value" is booked hours in the '
        'next 7 days and "date" the heaviest day.',
  );
}

/// Spending expected over the next seven days from weekday habits.
LifeForecast? forecastWeekSpend(LifeInputs i) {
  if (i.dailySpend.isEmpty) return null;
  const window = 56;
  final firstSpend = i.dailySpend.keys.reduce((a, b) => a.isBefore(b) ? a : b);
  if (i.today.difference(firstSpend).inDays < 28) return null;
  // Days before the first recorded expense are unknown, not zero.
  var start = i.today.subtract(const Duration(days: window));
  if (firstSpend.isAfter(start)) start = firstSpend;
  final byWeekday = <int, List<double>>{};
  final all = <double>[];
  for (var d = start; d.isBefore(i.today); d = d.add(const Duration(days: 1))) {
    final v = i.dailySpend[d] ?? 0;
    byWeekday.putIfAbsent(d.weekday, () => []).add(v);
    all.add(v);
  }
  final overall = mean(all);
  if (overall <= 0) return null;
  final days = [for (var d = 1; d <= 7; d++) i.today.add(Duration(days: d))];
  final expected = {
    for (final d in days)
      d: 0.6 * mean(byWeekday[d.weekday] ?? [overall]) + 0.4 * overall,
  };
  final total = expected.values.fold<double>(0, (a, v) => a + v);
  final last7 = [
    for (var b = 1; b <= 7; b++)
      i.dailySpend[i.today.subtract(Duration(days: b))] ?? 0,
  ].fold<double>(0, (a, v) => a + v);
  final priciest = days.reduce((a, b) => expected[a]! >= expected[b]! ? a : b);
  final above = last7 > 0 && total >= last7 * 1.25;
  return LifeForecast(
    kind: LifeForecastKind.weekSpend,
    headline: '~${moneyLabel(total, i.currency)}',
    detail:
        'Expected spending over the next 7 days, against '
        '${moneyLabel(last7, i.currency)} in the last 7. '
        '${weekdayShort(priciest)} is usually your priciest day ahead.',
    date: priciest,
    attention: above,
    notes: [
      'Each day blends its weekday average (60%) with your overall daily average (40%) over up to the last $window days.',
      'Typical day: ${moneyLabel(overall, i.currency)}.',
      'Known bills are not added separately; they are already part of past spending.',
    ],
    signature: fingerprint([total, last7, priciest]),
    rawData: dailySpendRows(i.spending, i.now),
    question:
        'Predict my total spending for the next 7 days starting '
        '${dateLine.format(i.today.add(const Duration(days: 1)))} from the '
        'daily rows, using weekday habits and ignoring one-off spikes. '
        '"value" is the total and "date" the day most likely to be '
        'the most expensive.',
  );
}
