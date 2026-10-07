import 'package:intl/intl.dart';

import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';
import 'package:personal/features/forecasts/life_raw_data.dart';

final _time = DateFormat('HH:mm');

/// One day's door-to-door trip: leaving home to arriving at work.
typedef CommuteSample = ({DateTime day, DateTime left, DateTime arrived});

List<CommuteSample> commuteSamples(LifeInputs i) {
  final visits = [
    for (final v in i.placeVisits)
      if (!v.isNested) v,
  ];
  final workStart = <DateTime, DateTime>{};
  for (final v in visits) {
    if (!v.isAtWork) continue;
    final d = dayOf(v.startTime);
    final cur = workStart[d];
    if (cur == null || v.startTime.isBefore(cur)) workStart[d] = v.startTime;
  }
  final out = <CommuteSample>[];
  for (final e in workStart.entries) {
    DateTime? left;
    for (final v in visits) {
      if (!v.isAtHome || dayOf(v.endTime) != e.key) continue;
      if (v.endTime.isAfter(e.value)) continue;
      if (left == null || v.endTime.isAfter(left)) left = v.endTime;
    }
    if (left == null) continue;
    final minutes = e.value.difference(left).inMinutes;
    if (minutes < 5 || minutes > 180) continue;
    out.add((day: e.key, left: left.toLocal(), arrived: e.value.toLocal()));
  }
  out.sort((a, b) => a.day.compareTo(b.day));
  return out;
}

String commuteRows(LifeInputs i) {
  final s = commuteSamples(i);
  if (s.isEmpty) return '- no home-to-work trips found';
  return [
    'date | left home | reached work | minutes',
    for (final c in s)
      '${dateLine.format(c.day)} | ${_time.format(c.left)} | '
          '${_time.format(c.arrived)} | ${c.arrived.difference(c.left).inMinutes}',
  ].join('\n');
}

/// Door-to-door minutes to work, by weekday and lately.
LifeForecast? forecastCommute(LifeInputs i) {
  final samples = commuteSamples(i);
  if (samples.length < 5) return null;
  final minutes = [
    for (final s in samples) s.arrived.difference(s.left).inMinutes.toDouble(),
  ];
  final byDay = <int, List<double>>{};
  for (var k = 0; k < samples.length; k++) {
    byDay.putIfAbsent(samples[k].day.weekday, () => []).add(minutes[k]);
  }
  final recent = minutes.length > 10
      ? minutes.sublist(minutes.length - 10)
      : minutes;
  final usual = median(recent);
  final slowest = byDay.entries
      .where((e) => e.value.length >= 2)
      .fold<MapEntry<int, List<double>>?>(
        null,
        (best, e) =>
            best == null || mean(e.value) > mean(best.value) ? e : best,
      );
  final leftTimes = [
    for (final s
        in samples.length > 10 ? samples.sublist(samples.length - 10) : samples)
      minutesOfDay(s.left).toDouble(),
  ];
  return LifeForecast(
    kind: LifeForecastKind.commute,
    headline: '~${usual.round()} min',
    detail:
        'usually leave ${clockLabel(mean(leftTimes))}'
        '${slowest == null ? '' : ' · slowest ${weekdayShort(DateTime(2024, 1, slowest.key))} (${mean(slowest.value).round()})'}',
    notes: [
      'Median of your last ${recent.length} home-to-work trips, from when you left home to when you reached work.',
      'Slowest trip ${minutes.reduce((a, b) => a > b ? a : b).round()} min, fastest ${minutes.reduce((a, b) => a < b ? a : b).round()} min over ${samples.length} days.',
    ],
    signature: fingerprint([samples.length, samples.last.day, usual]),
    rawData: commuteRows(i),
    question:
        'Predict my door-to-door commute time on the next working day '
        '(today is ${dateLine.format(i.today)}) and the departure time that '
        'would get me to work on time. Use the trips: weekday differences, '
        'recent drift and outliers. "value" is minutes.',
  );
}

/// Chance of being at the office on each coming weekday.
LifeForecast? forecastOfficeDay(LifeInputs i) {
  final days = i.work.workDays;
  if (days.length < 10) return null;
  final first = dayOf(days.first.date);
  final weeks = (i.today.difference(first).inDays / 7).ceil().clamp(2, 60);
  final count = <int, int>{};
  for (final d in days) {
    count[d.date.weekday] = (count[d.date.weekday] ?? 0) + 1;
  }
  double chance(int weekday) => ((count[weekday] ?? 0) / weeks).clamp(0.0, 1.0);
  var next = i.today.add(const Duration(days: 1));
  for (var g = 0; g < 7 && chance(next.weekday) < 0.2; g++) {
    next = next.add(const Duration(days: 1));
  }
  final week = [
    for (var w = 1; w <= 5; w++)
      '${weekdayShort(DateTime(2024, 1, w))} ${(chance(w) * 100).round()}%',
  ];
  final p = chance(next.weekday);
  return LifeForecast(
    kind: LifeForecastKind.officeDay,
    headline: '${(p * 100).round()}% office',
    detail:
        '${weekdayShort(next)} ${shortDate.format(next)} · ${week.join(' ')}',
    date: next,
    notes: [
      'Share of weeks over the last $weeks in which you were at work on that weekday.',
    ],
    signature: fingerprint([days.length, days.last.date, p]),
    rawData: workRows(i),
    question:
        'For each of the next 7 days from ${dateLine.format(i.today)}, '
        'estimate the probability I will be at the office rather than home '
        'or elsewhere. Count the weeks covered by the rows and how often '
        'each weekday has a visit; allow for holidays and events in the '
        'calendar. "value" is the probability for the next likely office day '
        'and "date" that day.',
  );
}

/// Riding distance next week.
LifeForecast? forecastWeeklyKm(LifeInputs i) {
  final monday = i.today.subtract(Duration(days: i.today.weekday - 1));
  final weeks = List<double>.filled(8, 0);
  var thisWeek = 0.0;
  for (final a in i.activities) {
    if (!a.isMotorcycling || a.distanceMeters <= 0) continue;
    final d = dayOf(a.startTime);
    final km = a.distanceMeters / 1000;
    if (!d.isBefore(monday)) {
      thisWeek += km;
      continue;
    }
    final ago = monday.difference(d).inDays ~/ 7;
    if (ago < weeks.length) weeks[weeks.length - 1 - ago] += km;
  }
  if (weeks.where((w) => w > 0).length < 3) return null;
  final xs = [for (var k = 0; k < weeks.length; k++) k.toDouble()];
  final trend = slope(xs, weeks) ?? 0;
  final expected = 0.6 * ewma(weeks, alpha: 0.4) + 0.4 * mean(weeks.skip(4));
  return LifeForecast(
    kind: LifeForecastKind.weeklyKm,
    headline: '~${expected.round()} km',
    detail:
        'next week · ${signed(trend, digits: 0)} km/week trend · ${thisWeek.round()} km so far',
    notes: [
      'Weekly km, oldest first: ${weeks.map((w) => w.round()).join(', ')}.',
    ],
    signature: fingerprint([thisWeek, expected]),
    rawData: dailyKmRowsFor(i),
    question:
        'Predict my motorcycle km for next week (the week after '
        '${dateLine.format(i.today)}) and this week\'s final total. Total '
        'the daily rows into weeks yourself and weigh recent weeks, weekday '
        'habits and any holidays or events in the calendar. "value" is km '
        'next week.',
  );
}

/// The regular place you are due to visit next.
LifeForecast? forecastRevisit(LifeInputs i) {
  final visits = <String, List<DateTime>>{};
  final label = <String, String>{};
  for (final v in i.placeVisits) {
    if (v.isNested || v.isAtHome || v.isAtWork) continue;
    final id = v.placeId ?? v.name;
    if (id.trim().isEmpty) continue;
    visits.putIfAbsent(id, () => []).add(dayOf(v.startTime));
    final named = i.placeNames[id] ?? (v.name.trim().isEmpty ? null : v.name);
    if (named != null) label[id] = named;
  }
  String? best;
  DateTime? bestDate;
  var bestGap = 0.0;
  var bestLast = i.today;
  for (final e in visits.entries) {
    final days = {...e.value}.toList()..sort();
    if (days.length < 4) continue;
    final gaps = [
      for (var k = 1; k < days.length; k++)
        days[k].difference(days[k - 1]).inDays.toDouble(),
    ].where((g) => g > 0).toList();
    if (gaps.length < 3) continue;
    final gap = median(gaps);
    if (gap < 2 || gap > 60) continue;
    final due = days.last.add(Duration(days: gap.round()));
    if (due.isBefore(i.today.subtract(Duration(days: (gap * 1.5).round())))) {
      continue;
    }
    if (bestDate == null || due.isBefore(bestDate)) {
      best = e.key;
      bestDate = due;
      bestGap = gap;
      bestLast = days.last;
    }
  }
  if (best == null || bestDate == null) return null;
  final name = label[best] ?? 'A regular place';
  final overdue = bestDate.isBefore(i.today);
  final next = overdue ? i.today : bestDate;
  return LifeForecast(
    kind: LifeForecastKind.revisit,
    headline: name.length > 22 ? '${name.substring(0, 21)}…' : name,
    detail:
        '${overdue ? 'due now' : 'around ${shortDate.format(bestDate)}'} · '
        'every ~${bestGap.round()} days · last ${shortDate.format(bestLast)}',
    date: next,
    notes: [
      'Median gap between your visits to this place, added to the last visit.',
    ],
    signature: fingerprint([best, bestLast, bestGap]),
    rawData: placeVisitRows(i, visits, label),
    question:
        'From each place\'s visit dates, find the regular place I am next '
        'due to visit (today is ${dateLine.format(i.today)}): work out its '
        'usual gap and weekday habit and add them to the last visit. '
        '"headline" is the place name, "date" the expected visit.',
  );
}

String placeVisitRows(
  LifeInputs i,
  Map<String, List<DateTime>> visits,
  Map<String, String> label,
) {
  final ranked = visits.entries.toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  if (ranked.isEmpty) return '- no place visits';
  final out = StringBuffer('place | visit dates (oldest first)\n');
  for (final e in ranked.take(20)) {
    final days = {...e.value}.toList()..sort();
    out.writeln(
      '${label[e.key] ?? 'place ${e.key.substring(0, e.key.length.clamp(0, 6))}'} | '
      '${days.skip(days.length > 15 ? days.length - 15 : 0).map((d) => DateFormat('yyyy-MM-dd').format(d)).join(', ')}',
    );
  }
  return out.toString().trimRight();
}

String dailyKmRowsFor(LifeInputs i) {
  final km = <DateTime, double>{};
  for (final a in i.activities) {
    if (!a.isMotorcycling || a.distanceMeters <= 0) continue;
    final d = dayOf(a.startTime);
    if (i.today.difference(d).inDays > 70) continue;
    km[d] = (km[d] ?? 0) + a.distanceMeters / 1000;
  }
  if (km.isEmpty) return '- no riding recorded';
  final keys = km.keys.toList()..sort();
  return [
    'date | km (days not listed had no riding)',
    for (final d in keys)
      '${dateLine.format(d)} | ${km[d]!.toStringAsFixed(1)}',
  ].join('\n');
}
