import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/forecasts/life/life_raw_data.dart';
import 'package:personal/features/journal/data/journal_models.dart';

/// Check-ins needed before energy is reported at all.
const energyMinCheckIns = 7;

/// Paired days needed before a habit is linked to energy or sleep.
const habitMinPairs = 8;

const _minR = 0.3;

DateTime _dayBefore(DateTime d) => DateTime(d.year, d.month, d.day - 1);
DateTime _dayAfter(DateTime d) => DateTime(d.year, d.month, d.day + 1);

/// Hours slept on the night that ended on each wake date.
Map<DateTime, double> _sleepByWake(LifeInputs i) => {
  for (final n in i.nights)
    if (n.session != null)
      dayOf(n.wakeDate): n.session!.duration.inMinutes / 60,
};

/// Something known by the morning that may move how the day feels.
class _Driver {
  const _Driver(this.name, this.unit, this.valueFor);

  final String name;

  /// What one step of the driver is, as in "each extra hour of sleep".
  final String unit;

  /// The driver's value for the day being felt; null when unknown.
  final double? Function(DateTime day) valueFor;
}

/// How today is likely to feel, from whichever habit tracks energy best.
LifeForecast? forecastEnergy(LifeInputs i) {
  final checkIns = i.journal.checkIns;
  if (checkIns.length < energyMinCheckIns) return null;

  final sleep = _sleepByWake(i);
  final screen = screenHoursByDay(i);
  final games = <DateTime, double>{};
  for (final g in i.games) {
    final d = dayOf(g.sessionDate);
    games[d] = (games[d] ?? 0) + g.timePlayed.inMinutes / 60;
  }
  final coffees = i.journal.countByDay(IntakeKind.caffeine);
  final drivers = [
    _Driver('sleep the night before', 'hour of sleep', (d) => sleep[d]),
    _Driver(
      'screen time the day before',
      'hour on your phone',
      (d) => screen[_dayBefore(d)],
    ),
    if (games.isNotEmpty)
      _Driver(
        'gaming the day before',
        'hour of gaming',
        (d) => games[_dayBefore(d)] ?? 0,
      ),
    _Driver('when you put the phone down', 'hour later', (d) {
      final p = i.phone.on(_dayBefore(d));
      final m = p != null && p.complete ? p.lastUseMinutes : null;
      return m == null ? null : m / 60;
    }),
    if (coffees.isNotEmpty)
      _Driver(
        'coffees the day before',
        'coffee',
        (d) => (coffees[_dayBefore(d)] ?? 0).toDouble(),
      ),
  ];

  _Driver? best;
  double bestR = 0;
  double bestSlope = 0;
  double bestMeanX = 0;
  double bestMeanY = 0;
  var bestPairs = 0;
  for (final driver in drivers) {
    final xs = <double>[];
    final ys = <double>[];
    for (final c in checkIns) {
      final x = driver.valueFor(c.day);
      if (x == null) continue;
      xs.add(x);
      ys.add(c.energy.toDouble());
    }
    if (xs.length < habitMinPairs) continue;
    final r = pearson(xs, ys);
    final s = slope(xs, ys);
    if (r == null || s == null || r.abs() < _minR) continue;
    if (r.abs() > bestR.abs()) {
      best = driver;
      bestR = r;
      bestSlope = s;
      bestMeanX = mean(xs);
      bestMeanY = mean(ys);
      bestPairs = xs.length;
    }
  }

  final recent = checkIns.length > 7
      ? checkIns.sublist(checkIns.length - 7)
      : checkIns;
  final avgEnergy = mean(recent.map((c) => c.energy));
  final avgMood = mean(recent.map((c) => c.mood));
  final avgStress = mean(recent.map((c) => c.stress));
  final feel =
      'Last ${recent.length} check-ins: energy ${avgEnergy.toStringAsFixed(1)}, '
      'mood ${avgMood.toStringAsFixed(1)}, stress ${avgStress.toStringAsFixed(1)} out of 5.';
  const question =
      'Work out which of my habits (sleep, screen time, gaming, coffees, '
      'when I put the phone down) best explains the energy column, then '
      'predict my energy for today on the 1-5 scale. "value" is that energy.';

  final todayX = best?.valueFor(i.today);
  if (best == null || todayX == null) {
    return LifeForecast(
      kind: LifeForecastKind.energy,
      headline: '${avgEnergy.toStringAsFixed(1)} / 5',
      detail:
          '$feel '
          '${best == null ? 'No single habit explains your energy yet.' : 'Your energy follows ${best.name}, but today\'s figure is not in yet.'}',
      attention: avgEnergy <= 2.5,
      notes: [
        'This is your recent average, not a prediction: a habit is only '
            'used once it lines up with energy on $habitMinPairs or more days.',
      ],
      signature: fingerprint([checkIns.length, avgEnergy, best?.name]),
      rawData: patternRows(i),
      question: question,
    );
  }

  final predicted = (bestMeanY + bestSlope * (todayX - bestMeanX)).clamp(
    1.0,
    5.0,
  );
  final effect = bestSlope.abs();
  return LifeForecast(
    kind: LifeForecastKind.energy,
    headline: '~${predicted.toStringAsFixed(1)} / 5',
    detail:
        'Expected energy today. It follows ${best.name} most: each extra '
        '${best.unit} ${bestSlope >= 0 ? 'adds' : 'costs'} about '
        '${effect.toStringAsFixed(1)} of a point. $feel',
    date: i.today,
    attention: predicted <= 2.5,
    notes: [
      'Compared your energy check-ins with ${drivers.length} habits and kept the strongest link: ${best.name} over $bestPairs days (r = ${bestR.toStringAsFixed(2)}).',
      'A link is not proof of cause. It gets steadier with more check-ins.',
    ],
    signature: fingerprint([checkIns.length, best.name, bestR, predicted]),
    rawData: patternRows(i),
    question: question,
  );
}

LifeForecast? _lastIntakeVsSleep(
  LifeInputs i, {
  required LifeForecastKind kind,
  required IntakeKind intake,
}) {
  final last = i.journal.lastMinutesByDay(intake);
  if (last.length < habitMinPairs) return null;
  final sleep = _sleepByWake(i);
  final xs = <double>[];
  final ys = <double>[];
  for (final e in last.entries) {
    final night = sleep[_dayAfter(e.key)];
    if (night == null) continue;
    xs.add(e.value / 60);
    ys.add(night);
  }
  if (xs.length < habitMinPairs) return null;
  final r = pearson(xs, ys);
  final s = slope(xs, ys);
  final noun = intake.noun;
  final days = last.keys.toList()..sort();
  final recentDays = days.length > 7 ? days.sublist(days.length - 7) : days;
  final recent = median(recentDays.map((d) => last[d]!));
  final question =
      'Work out how the time of my last $noun of the day (last $noun column) '
      'relates to how long I sleep that night (the sleep row dated the next '
      'day), and the latest time I can have it without losing sleep. '
      '"headline" is that time.';

  if (r == null || s == null || r > -0.25) {
    return LifeForecast(
      kind: kind,
      headline: 'No clear effect',
      detail:
          'Over ${xs.length} days, how late your last $noun was made no '
          'measurable difference to that night\'s sleep. Lately it is around '
          '${clockLabel(recent)}.',
      notes: [
        'Paired the last $noun of each day with the sleep that followed'
            '${r == null ? '' : ' (r = ${r.toStringAsFixed(2)})'}.',
      ],
      signature: fingerprint([xs.length, r, recent]),
      rawData: patternRows(i),
      question: question,
    );
  }

  // The cut-off is where the last one fell on the better half of nights.
  final typicalSleep = median(ys);
  final cutoff =
      median([
        for (var k = 0; k < xs.length; k++)
          if (ys[k] >= typicalSleep) xs[k],
      ]) *
      60;
  final late = recent > cutoff + 30;
  return LifeForecast(
    kind: kind,
    headline: 'By ${clockLabel(cutoff)}',
    detail:
        'Each hour later your last $noun is, you sleep about '
        '${(s.abs() * 60).round()} minutes less that night. On your better '
        'nights it was by ${clockLabel(cutoff)}; lately it is around '
        '${clockLabel(recent)}.',
    attention: late,
    notes: [
      'Paired the last $noun of each day with the sleep that followed over ${xs.length} days (r = ${r.toStringAsFixed(2)}).',
      'The cut-off is the middle last-$noun time on nights you slept ${hoursLabel(typicalSleep)} or more.',
    ],
    signature: fingerprint([xs.length, r, cutoff, recent]),
    rawData: patternRows(i),
    question: question,
  );
}

/// How late a coffee can be before the night's sleep gets shorter.
LifeForecast? forecastCaffeineCutoff(LifeInputs i) => _lastIntakeVsSleep(
  i,
  kind: LifeForecastKind.caffeine,
  intake: IntakeKind.caffeine,
);

/// How late the last meal can be before the night's sleep gets shorter.
LifeForecast? forecastLateMeal(LifeInputs i) => _lastIntakeVsSleep(
  i,
  kind: LifeForecastKind.lateMeal,
  intake: IntakeKind.meal,
);

/// When the phone goes down at night, whether that is drifting later, and
/// what it does to sleep.
LifeForecast? forecastPhoneDown(LifeInputs i) {
  final days = [
    for (final d in i.phone.completeDays)
      if (d.lastUseMinutes != null) d,
  ];
  if (days.length < 7) return null;
  final recentCount = days.length >= 21 ? 7 : 3;
  final recent = days.sublist(days.length - recentCount);
  final earlier = days.sublist(0, days.length - recentCount);
  final now = mean(recent.map((d) => d.lastUseMinutes!));
  final usual = mean(earlier.map((d) => d.lastUseMinutes!));
  final drift = now - usual;
  final pickups = mean(recent.map((d) => d.pickups));
  final usualPickups = mean(earlier.map((d) => d.pickups));

  final sleep = _sleepByWake(i);
  final xs = <double>[];
  final ys = <double>[];
  for (final d in days) {
    final night = sleep[_dayAfter(d.day)];
    if (night == null) continue;
    xs.add(d.lastUseMinutes! / 60);
    ys.add(night);
  }
  final r = xs.length >= habitMinPairs ? pearson(xs, ys) : null;
  final s = xs.length >= habitMinPairs ? slope(xs, ys) : null;
  final costs = r != null && s != null && r <= -0.25;

  final driftText = drift.abs() < 10
      ? 'in line with your usual ${clockLabel(usual)}'
      : '${drift.abs().round()} minutes ${drift > 0 ? 'later' : 'earlier'} '
            'than your usual ${clockLabel(usual)}';
  return LifeForecast(
    kind: LifeForecastKind.phoneDown,
    headline: clockLabel(now),
    detail:
        'You put the phone down around ${clockLabel(now)} over the last '
        '$recentCount nights, $driftText. '
        '${costs ? 'Each half hour later costs about ${(s.abs() * 30).round()} minutes of sleep. ' : ''}'
        'You pick it up about ${pickups.round()} times a day'
        '${usualPickups == 0 ? '' : ' (usually ${usualPickups.round()})'}.',
    attention: drift >= 30,
    notes: [
      'Phone-down time is the last time the screen went off after being unlocked, with the day ending at 04:00.',
      'Compared the last $recentCount nights with the ${earlier.length} before them.',
      if (r != null)
        'Paired with the sleep that followed over ${xs.length} nights (r = ${r.toStringAsFixed(2)}).',
    ],
    signature: fingerprint([days.length, now, usual, pickups, r]),
    rawData: patternRows(i),
    question:
        'Work out when I usually put my phone down at night (phone put down '
        'column), whether that is drifting later, and how it relates to the '
        'sleep that follows (the sleep row dated the next day). "headline" '
        'is tonight\'s likely phone-down time.',
  );
}
