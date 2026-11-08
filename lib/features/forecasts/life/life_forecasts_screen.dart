import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/forecasts/life/life_raw_data.dart';

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
