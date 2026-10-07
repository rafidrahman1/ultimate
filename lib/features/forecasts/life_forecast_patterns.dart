import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';
import 'package:personal/features/forecasts/life_raw_data.dart';
import 'package:personal/features/health/vitals_models.dart';

class _Link {
  const _Link({
    required this.cause,
    required this.r,
    required this.n,
    required this.slopePerUnit,
    required this.unit,
    required this.todayValue,
    required this.baseline,
  });

  final String cause;
  final double r;
  final int n;

  /// Hours of sleep gained per unit of [cause] the day before.
  final double slopePerUnit;
  final String unit;

  /// Today's value of the cause, when known.
  final double? todayValue;

  /// Mean sleep, to centre the adjustment on.
  final double baseline;
}

/// Looks for what moves your sleep: gaming, calendar load, steps and spending
/// on the day before a night. Reports the strongest link and what it implies
/// for tonight.
LifeForecast? forecastPatterns(LifeInputs i) {
  final sleepByWake = {
    for (final n in i.nights)
      if (n.session != null)
        dayOf(n.wakeDate): n.session!.duration.inMinutes / 60,
  };
  if (sleepByWake.length < 10) return null;

  final games = <DateTime, double>{};
  for (final g in i.games) {
    final d = dayOf(g.sessionDate);
    games[d] = (games[d] ?? 0) + g.timePlayed.inMinutes / 60;
  }
  final cal = eventHoursByDay(i);
  final steps = {
    for (final d in i.vitals?.days ?? const <DailyVitals>[])
      if (d.steps != null) dayOf(d.date): d.steps! / 1000.0,
  };
  final hasGames = i.games.isNotEmpty;
  final baseline = mean(sleepByWake.values);

  _Link? link(
    String cause,
    String unit,
    Map<DateTime, double> source, {
    required bool missingIsZero,
  }) {
    final xs = <double>[];
    final ys = <double>[];
    for (final e in sleepByWake.entries) {
      final dayBefore = e.key.subtract(const Duration(days: 1));
      final x = source[dayBefore] ?? (missingIsZero ? 0.0 : null);
      if (x == null) continue;
      xs.add(x);
      ys.add(e.value);
    }
    if (xs.length < 10) return null;
    final r = pearson(xs, ys);
    final s = slope(xs, ys);
    if (r == null || s == null) return null;
    return _Link(
      cause: cause,
      r: r,
      n: xs.length,
      slopePerUnit: s,
      unit: unit,
      todayValue: source[i.today] ?? (missingIsZero ? 0.0 : null),
      baseline: baseline,
    );
  }

  final links = <_Link>[
    if (hasGames) ?link('gaming', 'h', games, missingIsZero: true),
    ?link('calendar load', 'h', cal, missingIsZero: true),
    if (steps.isNotEmpty)
      ?link('steps', 'k steps', steps, missingIsZero: false),
    if (i.dailySpend.isNotEmpty)
      ?link('spending', 'k spent', {
        for (final e in i.dailySpend.entries) e.key: e.value / 1000,
      }, missingIsZero: true),
  ]..sort((a, b) => b.r.abs().compareTo(a.r.abs()));
  final best = links.isEmpty ? null : links.first;
  if (best == null || best.r.abs() < 0.3) return null;

  final minutesPerUnit = best.slopePerUnit * 60;
  final direction = best.r < 0 ? 'less' : 'more';
  final xMean = best.todayValue == null
      ? null
      : best.todayValue! - _meanOf(best, sleepByWake, games, cal, steps, i);
  final tonight = xMean == null
      ? null
      : (best.baseline + best.slopePerUnit * xMean).clamp(3.0, 12.0);
  final strong = best.r.abs() >= 0.5;

  return LifeForecast(
    kind: LifeForecastKind.patterns,
    headline:
        '${best.cause[0].toUpperCase()}${best.cause.substring(1)} ↔ sleep',
    detail:
        '${minutesPerUnit.abs().round()} min $direction sleep per ${best.unit}'
        '${tonight == null ? '' : ' · tonight ~${hoursLabel(tonight)}'}',
    attention: strong && best.r < 0 && tonight != null && tonight < 6.5,
    notes: [
      'Compared each day\'s ${best.cause} with sleep the following night over ${best.n} days (r = ${best.r.toStringAsFixed(2)}).',
      for (final l in links.skip(1).take(3))
        'Weaker: ${l.cause} (r = ${l.r.toStringAsFixed(2)}, ${l.n} days).',
      if (!strong) 'The link is moderate; treat it as a hint, not a rule.',
    ],
    signature: fingerprint([sleepByWake.length, best.cause, best.r]),
    rawData: patternRows(i),
    question:
        'Find which daily habits move my sleep. From the daily rows, work out '
        'how each of gaming, calendar hours, steps and spending on a day '
        'relates to the sleep of the following night (the night ending the '
        'next date), pick the strongest, and use today\'s partial values to '
        'estimate tonight\'s sleep. "headline" names the link, "value" is '
        'tonight\'s expected hours.',
  );
}

double _meanOf(
  _Link link,
  Map<DateTime, double> sleep,
  Map<DateTime, double> games,
  Map<DateTime, double> cal,
  Map<DateTime, double> steps,
  LifeInputs i,
) {
  final source = switch (link.cause) {
    'gaming' => games,
    'calendar load' => cal,
    'steps' => steps,
    _ => {for (final e in i.dailySpend.entries) e.key: e.value / 1000},
  };
  final values = <double>[];
  for (final wake in sleep.keys) {
    final v = source[wake.subtract(const Duration(days: 1))];
    if (v != null) values.add(v);
  }
  // Days with no entry count as zero for the "missing is zero" sources.
  final missing = sleep.length - values.length;
  if (link.cause != 'steps' && missing > 0) {
    return values.fold<double>(0, (a, b) => a + b) / sleep.length;
  }
  return mean(values);
}
