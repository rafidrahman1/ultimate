import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';
import 'package:personal/features/forecasts/life_raw_data.dart';

/// When you will reach work on your next working day, and how likely you are
/// to be late.
LifeForecast? forecastWorkArrival(LifeInputs i) {
  final days = [...i.work.workDays]..sort((a, b) => a.date.compareTo(b.date));
  if (days.length < 5) return null;
  final minutes = [
    for (final d in days) minutesOfDay(d.arrivalTime).toDouble(),
  ];
  final byWeekday = <int, List<WorkDayLike>>{};
  for (var k = 0; k < days.length; k++) {
    byWeekday
        .putIfAbsent(days[k].date.weekday, () => [])
        .add(WorkDayLike(minutes[k], days[k].isLate));
  }

  // Next day you usually work: tomorrow onward, or today if no arrival yet.
  final usual = {
    for (final e in byWeekday.entries)
      if (e.value.length >= 2) e.key,
  };
  final arrivedToday = days.any((d) => dayOf(d.date) == i.today);
  var next = arrivedToday ? i.today.add(const Duration(days: 1)) : i.today;
  for (var guard = 0; guard < 8 && !usual.contains(next.weekday); guard++) {
    next = next.add(const Duration(days: 1));
  }
  if (!usual.contains(next.weekday)) return null;

  final sameDay = byWeekday[next.weekday]!;
  final recent = minutes.length > 10
      ? minutes.sublist(minutes.length - 10)
      : minutes;
  final expected =
      0.5 * mean(recent) + 0.5 * mean(sameDay.map((d) => d.minutes));
  final lateShare = sameDay.where((d) => d.late).length / sameDay.length;
  final overallLate = days.where((d) => d.isLate).length / days.length;
  final chance = (0.6 * lateShare + 0.4 * overallLate).clamp(0.0, 1.0);
  final scheduled = i.work.scheduledArrivalLabel;
  final hasSchedule = i.work.hasLateThreshold;

  return LifeForecast(
    kind: LifeForecastKind.workArrival,
    headline: '~${clockLabel(expected)}',
    detail:
        '${_weekday(next)}${hasSchedule ? ' · ${(chance * 100).round()}% chance late' : ''}'
        ' · ${days.length} days sampled',
    date: next,
    attention: hasSchedule && chance >= 0.5,
    notes: [
      'Blend of your last ${recent.length} arrivals (${clockLabel(mean(recent))}) and your ${sameDay.length} past ${_weekday(next)}s (${clockLabel(mean(sameDay.map((d) => d.minutes)))}).',
      if (hasSchedule)
        'Scheduled ${scheduled.isEmpty ? 'start' : scheduled}; late means after ${i.work.thresholdLabel}. You were late on ${(lateShare * 100).round()}% of ${_weekday(next)}s and ${(overallLate * 100).round()}% of all days.',
    ],
    signature: fingerprint([days.length, days.last.date, expected]),
    rawData:
        '${workRows(i)}\n\nSleep the nights before:\n${sleepRows(i)}\n\nCalendar:\n${calendarRows(i)}',
    question:
        'Predict my arrival time at work on ${dateLine.format(next)} and the '
        'probability I arrive late. Work from the arrival rows: weekday habit, '
        'recent drift, whether short sleep the night before made me later, and '
        'any early event or holiday on that day. "value" is the lateness '
        'probability from 0 to 1; "headline" is the arrival time as HH:mm.',
  );
}

class WorkDayLike {
  const WorkDayLike(this.minutes, this.late);
  final double minutes;
  final bool late;
}

String _weekday(DateTime d) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];

/// The most loaded day and week on the calendar over the next four weeks.
LifeForecast? forecastCalendarLoad(LifeInputs i) {
  final horizon = i.today.add(const Duration(days: 28));
  final upcoming = i.events.where((e) {
    final d = dayOf(e.start);
    return !d.isBefore(i.today) && !d.isAfter(horizon);
  }).toList();
  if (upcoming.isEmpty) return null;

  final hours = eventHoursByDay(i);
  final count = <DateTime, int>{};
  for (final e in upcoming) {
    if (e.isHoliday) continue;
    final d = dayOf(e.start);
    count[d] = (count[d] ?? 0) + 1;
  }
  final holidays = {
    for (final e in upcoming)
      if (e.isHoliday) dayOf(e.start),
  };

  var bestWeek = 0;
  var bestWeekScore = -1.0;
  final weekScores = <double>[];
  for (var w = 0; w < 4; w++) {
    var score = 0.0;
    for (var d = 0; d < 7; d++) {
      final day = i.today.add(Duration(days: w * 7 + d));
      score += (hours[day] ?? 0) + (count[day] ?? 0) * 0.5;
    }
    weekScores.add(score);
    if (score > bestWeekScore) {
      bestWeekScore = score;
      bestWeek = w;
    }
  }
  if (bestWeekScore <= 0 && holidays.isEmpty) return null;

  DateTime? busiestDay;
  var busiestScore = 0.0;
  for (final e in count.entries) {
    final score = (hours[e.key] ?? 0) + e.value * 0.5;
    if (score > busiestScore) {
      busiestScore = score;
      busiestDay = e.key;
    }
  }
  final weekStart = i.today.add(Duration(days: bestWeek * 7));
  final eventsThatWeek = count.entries
      .where(
        (e) =>
            !e.key.isBefore(weekStart) &&
            e.key.isBefore(weekStart.add(const Duration(days: 7))),
      )
      .fold<int>(0, (a, e) => a + e.value);
  final headline = busiestDay == null
      ? '${holidays.length} holiday${holidays.length == 1 ? '' : 's'}'
      : 'Week of ${shortDate.format(weekStart)}';
  final soon = busiestDay != null && busiestDay.difference(i.today).inDays <= 2;

  return LifeForecast(
    kind: LifeForecastKind.calendarLoad,
    headline: headline,
    detail: busiestDay == null
        ? 'Nothing timed in the next 4 weeks'
        : '$eventsThatWeek events · busiest ${shortDate.format(busiestDay)} (${(hours[busiestDay] ?? 0).toStringAsFixed(1)} h)'
              '${holidays.isEmpty ? '' : ' · ${holidays.length} holiday days'}',
    date: busiestDay ?? weekStart,
    attention: soon,
    notes: [
      'Each timed event hour counts 1 and each event 0.5, summed per week.',
      'Weekly load, next 4 weeks: ${weekScores.map((s) => s.toStringAsFixed(1)).join(', ')}.',
      if (holidays.isNotEmpty) '${holidays.length} holiday days in the window.',
    ],
    signature: fingerprint([upcoming.length, bestWeekScore]),
    rawData:
        '${calendarRows(i)}\n\nSleep, to see how busy days affect it:\n${sleepRows(i)}',
    question:
        'From the calendar rows, find the most demanding stretch in the next '
        '4 weeks (today is ${dateLine.format(i.today)}): back-to-back days, '
        'long days, early starts, travel or deadlines inferred from titles, '
        'balanced against holidays. "date" is the start of that stretch and '
        '"value" is the number of demanding days in it.',
  );
}

/// Gaming hours for the coming week from the weekly history.
LifeForecast? forecastGaming(LifeInputs i) {
  if (i.games.isEmpty) return null;
  // Monday-based week buckets, oldest to newest, for the last 8 full weeks.
  final monday = i.today.subtract(Duration(days: i.today.weekday - 1));
  final weeks = List<double>.filled(8, 0);
  final byGame = <String, double>{};
  var thisWeek = 0.0;
  for (final g in i.games) {
    final d = dayOf(g.sessionDate);
    final h = g.timePlayed.inMinutes / 60;
    if (!d.isBefore(monday)) {
      thisWeek += h;
      continue;
    }
    final ago = monday.difference(d).inDays ~/ 7;
    if (ago >= weeks.length) continue;
    weeks[weeks.length - 1 - ago] += h;
    byGame[g.name] = (byGame[g.name] ?? 0) + h;
  }
  final active = weeks.where((w) => w > 0).length;
  if (active < 2) return null;
  final xs = [for (var k = 0; k < weeks.length; k++) k.toDouble()];
  final trend = slope(xs, weeks) ?? 0;
  final expected = (0.6 * ewma(weeks, alpha: 0.4) + 0.4 * mean(weeks.skip(4)))
      .clamp(0.0, 168.0);
  final top = byGame.entries.isEmpty
      ? null
      : (byGame.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
  final rising = trend >= 1;
  return LifeForecast(
    kind: LifeForecastKind.gaming,
    headline: '~${expected.toStringAsFixed(1)} h next week',
    detail:
        '${signed(trend)} h/week trend · ${thisWeek.toStringAsFixed(1)} h so far this week'
        '${top == null ? '' : ' · mostly $top'}',
    attention: rising && expected >= 15,
    notes: [
      'Weighted average of the last 8 weeks, leaning on recent ones.',
      'Weekly hours, oldest first: ${weeks.map((w) => w.toStringAsFixed(1)).join(', ')}.',
    ],
    signature: fingerprint([i.games.length, thisWeek, expected]),
    rawData: gameRows(i),
    question:
        'Predict my total gaming hours for next week (Monday after '
        '${dateLine.format(i.today)}) and for the rest of this month. Total '
        'the daily rows into weeks yourself, then project from the trend and '
        'my weekday habits. "value" is hours next week.',
  );
}

/// Where the active checklist is likely to finish, from how its closed weeks
/// went.
LifeForecast? forecastChecklist(LifeInputs i) {
  final c = i.checklist;
  if (c == null || c.weeks.isEmpty) return null;
  final started = c.weeks.where((w) => !w.start.isAfter(i.today)).toList();
  if (started.isEmpty) return null;
  final total = c.weeks.fold<int>(0, (a, w) => a + w.total);
  if (total == 0) return null;
  final done = c.weeks.fold<int>(0, (a, w) => a + w.done);
  final closed = started.where((w) => w.end.isBefore(i.today) && w.total > 0);
  final closedRate = closed.isEmpty
      ? null
      : closed.fold<int>(0, (a, w) => a + w.done) /
            closed.fold<int>(0, (a, w) => a + w.total);
  final dueSoFar = started.fold<int>(0, (a, w) => a + w.total);
  final pace = dueSoFar == 0 ? 0.0 : done / dueSoFar;
  final rate = closedRate ?? pace;
  final remaining = total - dueSoFar;
  final projected = ((done + remaining * rate) / total).clamp(0.0, 1.0);
  final behind = projected < 0.6;
  return LifeForecast(
    kind: LifeForecastKind.checklist,
    headline: '~${(projected * 100).round()}% done',
    detail:
        '$done of $dueSoFar due items so far · ${c.weeks.length} weeks planned',
    attention: behind,
    notes: [
      closedRate == null
          ? 'No week has closed yet; pace is ${(pace * 100).round()}% of items due so far.'
          : 'Closed weeks finished ${(closedRate * 100).round()}% of their items; the rest is projected at that rate.',
      'Source: ${c.title}.',
    ],
    signature: fingerprint([done, dueSoFar, total]),
    rawData:
        '${checklistRows(i)}\n\nSleep and activity, which affect follow-through:\n${patternRows(i, days: 45)}',
    question:
        'Predict the share of this checklist I will have completed by the end '
        'of its last week (today is ${dateLine.format(i.today)}). Judge from '
        'how many items each closed week completed, how far into the current '
        'week I am, and whether later weeks are heavier. "value" is a 0 to 1 '
        'completion share.',
  );
}
