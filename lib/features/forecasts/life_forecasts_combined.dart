import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';
import 'package:personal/features/forecasts/life_raw_data.dart';
import 'package:personal/features/health/vitals_models.dart';

/// The longest open stretch on the calendar over the next two weeks.
LifeForecast? forecastFreeTime(LifeInputs i) {
  if (i.events.isEmpty) return null;
  final hours = eventHoursByDay(i);
  final holidays = {
    for (final e in i.events)
      if (e.isHoliday) dayOf(e.start),
  };
  final days = [for (var d = 0; d < 14; d++) i.today.add(Duration(days: d))];
  bool free(DateTime d) => (hours[d] ?? 0) < 1;

  var bestStart = 0;
  var bestLen = 0;
  var runStart = 0;
  var run = 0;
  for (var k = 0; k < days.length; k++) {
    if (free(days[k])) {
      if (run == 0) runStart = k;
      run++;
      if (run > bestLen) {
        bestLen = run;
        bestStart = runStart;
      }
    } else {
      run = 0;
    }
  }
  if (bestLen == 0) return null;
  final lightest = days.reduce(
    (a, b) => (hours[a] ?? 0) <= (hours[b] ?? 0) ? a : b,
  );
  final start = days[bestStart];
  final end = days[bestStart + bestLen - 1];
  final range = bestLen == 1
      ? shortDate.format(start)
      : '${shortDate.format(start)}–${shortDate.format(end)}';
  return LifeForecast(
    kind: LifeForecastKind.freeTime,
    headline: range,
    detail:
        '$bestLen open day${bestLen == 1 ? '' : 's'} · ${days.where(free).length} of 14 days light'
        '${holidays.any((h) => !h.isBefore(start) && !h.isAfter(end)) ? ' · includes a holiday' : ''}',
    date: start,
    notes: [
      'A day counts as open with under 1 hour of timed events.',
      'Lightest single day: ${shortDate.format(lightest)} (${(hours[lightest] ?? 0).toStringAsFixed(1)} h).',
    ],
    signature: fingerprint([i.events.length, bestLen, start]),
    rawData: calendarRows(i),
    question:
        'Find the best open stretch in the next 14 days (today is '
        '${dateLine.format(i.today)}): the longest run of days with little '
        'scheduled, also counting free hours inside lighter days. '
        '"headline" is the date range, "value" the number of open days and '
        '"date" its first day.',
  );
}

/// The kind of checklist item you tend to miss.
LifeForecast? forecastChecklistThemes(LifeInputs i) {
  final c = i.checklist;
  if (c == null) return null;
  final closed = c.weeks.where(
    (w) => w.end.isBefore(i.today) || w.start.isBefore(i.today),
  );
  final total = <String, int>{};
  final done = <String, int>{};
  for (final w in closed) {
    final isOpen = !w.end.isBefore(i.today);
    for (final e in w.byCategory.entries) {
      // The current week is still in progress, so only count its done items.
      total[e.key] =
          (total[e.key] ?? 0) + (isOpen ? e.value.done : e.value.total);
      done[e.key] = (done[e.key] ?? 0) + e.value.done;
    }
  }
  final rates = {
    for (final k in total.keys)
      if (total[k]! >= 3) k: done[k]! / total[k]!,
  };
  if (rates.length < 2) return null;
  final sorted = rates.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  final weak = sorted.first;
  final strong = sorted.last;
  if (strong.value - weak.value < 0.15) return null;
  return LifeForecast(
    kind: LifeForecastKind.checklistThemes,
    headline: weak.key,
    detail:
        '${(weak.value * 100).round()}% done · ${strong.key} ${(strong.value * 100).round()}%',
    attention: weak.value < 0.4,
    notes: [
      for (final e in sorted.take(5))
        '${e.key}: ${done[e.key]} of ${total[e.key]} items (${(e.value * 100).round()}%).',
    ],
    signature: fingerprint([weak.key, weak.value, total.length]),
    rawData: checklistRows(i),
    question:
        'From the checklist rows, work out which kind of item I complete '
        'least often and which most, and predict which category I will '
        'miss most in the weeks still to come. "headline" is that weakest '
        'category and "value" its expected completion share from 0 to 1.',
  );
}

/// How tired days change what you spend, and tomorrow's likely spend.
LifeForecast? forecastSleepSpend(LifeInputs i) {
  final tired = <double>[];
  final rested = <double>[];
  final hoursAll = <double>[];
  for (final n in i.nights) {
    final s = n.session;
    if (s == null) continue;
    final h = s.duration.inMinutes / 60;
    hoursAll.add(h);
    final spent = i.dailySpend[dayOf(n.wakeDate)] ?? 0;
    (h < 6.5 ? tired : rested).add(spent);
  }
  if (tired.length < 3 || rested.length < 3) return null;
  final tiredAvg = mean(tired);
  final restedAvg = mean(rested);
  if (restedAvg <= 0 && tiredAvg <= 0) return null;
  final tonight = ewma(hoursAll);
  final expected = tonight < 6.5 ? tiredAvg : restedAvg;
  final diff = tiredAvg - restedAvg;
  return LifeForecast(
    kind: LifeForecastKind.sleepSpend,
    headline: '~${moneyLabel(expected, i.currency)} tomorrow',
    detail:
        'after short sleep ${moneyLabel(tiredAvg, i.currency)} vs rested ${moneyLabel(restedAvg, i.currency)}',
    attention: diff > restedAvg * 0.3 && tonight < 6.5,
    notes: [
      'Short sleep means under 6.5 h: ${tired.length} such days against ${rested.length} rested days.',
      'Tomorrow uses your expected sleep of ${hoursLabel(tonight)} tonight.',
    ],
    signature: fingerprint([tired.length, rested.length, expected]),
    rawData: patternRows(i),
    question:
        'Compare what I spend on days that follow short sleep (under 6.5 h) '
        'with days after good sleep, using the daily rows. Then predict what '
        'I will spend tomorrow given my likely sleep tonight. "value" is '
        'tomorrow\'s expected spend.',
  );
}

/// The coming day that suits something demanding.
LifeForecast? forecastBestDay(LifeInputs i) {
  final sleepBy = <int, List<double>>{};
  for (final n in i.nights) {
    final s = n.session;
    if (s == null) continue;
    sleepBy
        .putIfAbsent(n.wakeDate.weekday, () => [])
        .add(s.duration.inMinutes / 60);
  }
  final stepBy = <int, List<double>>{};
  for (final d in i.vitals?.days ?? const <DailyVitals>[]) {
    if (d.steps != null) {
      stepBy.putIfAbsent(d.date.weekday, () => []).add(d.steps! / 1000.0);
    }
  }
  if (sleepBy.length < 4 && stepBy.length < 4) return null;
  final hours = eventHoursByDay(i);
  final dates = [for (var d = 1; d <= 14; d++) i.today.add(Duration(days: d))];
  final sleepAvg = {for (final e in sleepBy.entries) e.key: mean(e.value)};
  final stepAvg = {for (final e in stepBy.entries) e.key: mean(e.value)};
  double z(double v, Iterable<double> all) {
    final sd = stdDev(all);
    return sd == 0 ? 0 : (v - mean(all)) / sd;
  }

  final load = [for (final d in dates) hours[d] ?? 0.0];
  DateTime? best;
  var bestScore = -1e9;
  for (var k = 0; k < dates.length; k++) {
    final d = dates[k];
    var score = -z(load[k], load);
    if (sleepAvg.containsKey(d.weekday)) {
      score += z(sleepAvg[d.weekday]!, sleepAvg.values);
    }
    if (stepAvg.containsKey(d.weekday)) {
      score += z(stepAvg[d.weekday]!, stepAvg.values);
    }
    if (score > bestScore) {
      bestScore = score;
      best = d;
    }
  }
  if (best == null) return null;
  final sleepHere = sleepAvg[best.weekday];
  return LifeForecast(
    kind: LifeForecastKind.bestDay,
    headline: '${weekdayShort(best)} ${shortDate.format(best)}',
    detail:
        '${(hours[best] ?? 0).toStringAsFixed(1)} h booked'
        '${sleepHere == null ? '' : ' · you usually sleep ${hoursLabel(sleepHere)}'}',
    date: best,
    notes: [
      'Scores each of the next 14 days: lighter calendar, better sleep on that weekday and more activity all raise it.',
    ],
    signature: fingerprint([best, bestScore]),
    rawData: '${patternRows(i)}\n\nCalendar:\n${calendarRows(i)}',
    question:
        'Pick the best day in the next 14 days from ${dateLine.format(i.today)} '
        'for something demanding. Prefer days with a light calendar that '
        'fall on weekdays where I usually sleep well and move more. '
        '"headline" is the day and "date" the date.',
  );
}

/// A combined warning from sleep, heart rate, workload, lateness and
/// follow-through.
LifeForecast? forecastBurnout(LifeInputs i) {
  final parts = <(String, double, double)>[]; // label, weight, 0..1
  final hours = [
    for (final n in i.nights)
      if (n.session != null) n.session!.duration.inMinutes / 60,
  ];
  if (hours.length >= 5) {
    final last = hours.sublist(hours.length - 5);
    parts.add(('short sleep', 3, ((7.5 - mean(last)) / 2).clamp(0.0, 1.0)));
  }
  final rhr = [
    for (final d in i.vitals?.days ?? const <DailyVitals>[])
      if (d.restingHr != null) d.restingHr!.toDouble(),
  ];
  if (rhr.length >= 8) {
    final recent = mean(rhr.sublist(rhr.length - 3));
    final base = mean(rhr.sublist(0, rhr.length - 3));
    parts.add((
      'rising resting heart rate',
      2,
      ((recent - base) / 6).clamp(0.0, 1.0),
    ));
  }
  final cal = eventHoursByDay(i);
  final ahead = mean([
    for (var d = 0; d < 7; d++) cal[i.today.add(Duration(days: d))] ?? 0.0,
  ]);
  if (cal.isNotEmpty) {
    parts.add(('heavy calendar', 2, (ahead / 6).clamp(0.0, 1.0)));
  }
  final work = i.work.workDays;
  if (work.length >= 8 && i.work.hasLateThreshold) {
    final lastTen = work.length > 10 ? work.sublist(work.length - 10) : work;
    parts.add((
      'late arrivals',
      1,
      (lastTen.where((d) => d.isLate).length / lastTen.length).clamp(0.0, 1.0),
    ));
  }
  final steps = [
    for (final d in i.vitals?.days ?? const <DailyVitals>[])
      if (d.steps != null) d.steps!.toDouble(),
  ];
  if (steps.length >= 10) {
    final recent = mean(steps.sublist(steps.length - 3));
    final base = mean(steps.sublist(0, steps.length - 3));
    if (base > 0) {
      parts.add((
        'less movement',
        1,
        ((base - recent) / base * 2).clamp(0.0, 1.0),
      ));
    }
  }
  if (parts.length < 2) return null;
  final weight = parts.fold<double>(0, (a, p) => a + p.$2);
  final score = parts.fold<double>(0, (a, p) => a + p.$2 * p.$3) / weight * 100;
  final drivers = [...parts]
    ..sort((a, b) => (b.$2 * b.$3).compareTo(a.$2 * a.$3));
  final top = drivers
      .where((p) => p.$3 > 0.25)
      .take(2)
      .map((p) => p.$1)
      .toList();
  final level = score >= 60
      ? 'High'
      : score >= 35
      ? 'Moderate'
      : 'Low';
  return LifeForecast(
    kind: LifeForecastKind.burnout,
    headline: '$level · ${score.round()}',
    detail: top.isEmpty
        ? 'No strong warning signs'
        : 'Driven by ${top.join(' and ')}',
    attention: score >= 60,
    notes: [
      for (final p in drivers)
        '${p.$1}: ${(p.$3 * 100).round()}% of its warning level (weight ${p.$2.round()}).',
      'A rough guide from the signals available, not a medical assessment.',
    ],
    signature: fingerprint([score.round(), parts.length]),
    rawData:
        '${patternRows(i)}\n\nWork arrivals:\n${workRows(i)}\n\nCalendar:\n${calendarRows(i)}\n\nChecklist:\n${checklistRows(i)}',
    question:
        'Estimate my risk of burnout over the next 2 weeks from 0 to 100, '
        'judging sleep length, resting heart rate trend, calendar load '
        'ahead, late arrivals, activity and checklist follow-through in the '
        'rows. Name the one or two strongest drivers. "headline" is the '
        'level (Low, Moderate or High) with the score and "value" the '
        'score. This is a rough guide, not a medical assessment.',
  );
}
