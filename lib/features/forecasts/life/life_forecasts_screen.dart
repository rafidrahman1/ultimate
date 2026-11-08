import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/forecasts/life/life_raw_data.dart';

/// Phone time expected over the next week, from the recent daily totals.
LifeForecast? forecastScreenTime(LifeInputs i) {
  final byDay = screenHoursByDay(i);
  if (byDay.length < 5) return null;
  final days = byDay.keys.toList()..sort();
  final hours = [for (final d in days) byDay[d]!];
  final recent = hours.length > 7 ? hours.sublist(hours.length - 7) : hours;
  final earlier = hours.length > 7
      ? hours.sublist(0, hours.length - 7)
      : <double>[];
  final daily = 0.7 * mean(recent) + 0.3 * ewma(hours);
  final xs = [for (var k = 0; k < hours.length; k++) k.toDouble()];
  final trend = (slope(xs, hours) ?? 0) * 7;
  final rising = earlier.length >= 3 && mean(recent) - mean(earlier) >= 0.75;
  final apps = i.screen.topApps.take(3).map((a) => a.label).join(', ');
  // Weekday habit: the heaviest day of the week.
  final byWeekday = <int, List<double>>{};
  for (final d in days) {
    byWeekday.putIfAbsent(d.weekday, () => []).add(byDay[d]!);
  }
  final heaviest = byWeekday.entries.where((e) => e.value.length >= 2).toList()
    ..sort((a, b) => mean(b.value).compareTo(mean(a.value)));
  return LifeForecast(
    kind: LifeForecastKind.screenTime,
    headline: '~${hoursLabel(daily)}/day',
    detail:
        'About ${hoursLabel(daily * 7)} on your phone over the next week'
        '${heaviest.isEmpty ? '' : ', heaviest on ${weekdayShort(DateTime(2024, 1, heaviest.first.key))}s'}'
        '${rising ? '. It is climbing against earlier weeks' : ''}.',
    attention: rising || daily >= 6,
    notes: [
      'Last ${recent.length} days blended with a weighted average of all ${hours.length} days.',
      'Trend ${signed(trend, digits: 1)} h/day per week.',
      if (apps.isNotEmpty) 'Most used: $apps.',
    ],
    signature: fingerprint([hours.length, daily, days.last]),
    rawData:
        '${screenRows(i)}\n\nSleep, which screen time can affect:\n${sleepRows(i)}',
    question:
        'Predict my phone screen time per day for the next 7 days (starting '
        '${dateLine.format(i.today)}) and whether it is trending up or down. '
        'Use weekday habits and my calendar load if given. "value" is hours '
        'per day over the next 7 days.',
  );
}

/// How a day of phone use moves the following night's sleep.
LifeForecast? forecastScreenSleep(LifeInputs i) {
  final screen = screenHoursByDay(i);
  if (screen.length < 10 || i.nights.isEmpty) return null;
  final sleep = {for (final n in i.nights) dayOf(n.wakeDate): n.session!};
  final xs = <double>[];
  final ys = <double>[];
  for (final e in screen.entries) {
    final next = sleep[DateTime(e.key.year, e.key.month, e.key.day + 1)];
    if (next == null) continue;
    xs.add(e.value);
    ys.add(next.duration.inMinutes / 60);
  }
  if (xs.length < 10) return null;
  final r = pearson(xs, ys);
  final s = slope(xs, ys);
  if (r == null || s == null || r.abs() < 0.25) return null;
  final days = screen.keys.toList()..sort();
  final recentScreen = mean([
    for (final d in days.length > 7 ? days.sublist(days.length - 7) : days)
      screen[d]!,
  ]);
  final expected = mean(ys) + s * (recentScreen - mean(xs));
  final hurts = s < 0;
  return LifeForecast(
    kind: LifeForecastKind.screenSleep,
    headline: '~${hoursLabel(expected)}',
    detail:
        'Expected sleep tonight if today looks like your last week '
        '(${hoursLabel(recentScreen)} on your phone). Each extra hour of '
        'screen time ${hurts ? 'costs' : 'adds'} about '
        '${(s.abs() * 60).round()} minutes of sleep.',
    attention: hurts && expected < 6.5,
    notes: [
      'Paired each day\'s screen time with the next night\'s sleep over ${xs.length} days (r = ${r.toStringAsFixed(2)}).',
      if (hurts) 'Heavier screen days tend to be followed by shorter sleep.',
    ],
    signature: fingerprint([xs.length, r, expected]),
    rawData: patternRows(i),
    question:
        'Work out how my screen time on one day relates to how long I sleep '
        'the following night (the sleep row dated the next day), then predict '
        'tonight\'s sleep given my recent screen time. "value" is hours of '
        'sleep.',
  );
}
