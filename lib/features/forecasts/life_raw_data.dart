import 'package:intl/intl.dart';

import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';
import 'package:personal/features/health/vitals_models.dart';

/// Raw rows for each forecast, as compact text an AI can calculate from.
/// Nothing here is pre-digested: the baseline figures are given separately and
/// only as a cross-check.
final _time = DateFormat('HH:mm');

/// Local hour-of-day in minutes since midnight.
int minutesOfDay(DateTime d) {
  final l = d.toLocal();
  return l.hour * 60 + l.minute;
}

String sleepRows(LifeInputs i) {
  if (i.nights.isEmpty) return '- no sleep recorded';
  final out = StringBuffer(
    'wake date | bed | wake | hours asleep | deep/light/rem/awake minutes\n',
  );
  for (final n in i.nights) {
    final s = n.session!;
    final st = s.stages;
    out.writeln(
      '${dateLine.format(n.wakeDate)} | ${_time.format(s.startTime.toLocal())} '
      '| ${_time.format(s.endTime.toLocal())} '
      '| ${(s.duration.inMinutes / 60).toStringAsFixed(2)} | '
      '${st == null ? 'no stages' : '${st.deep.inMinutes}/${st.light.inMinutes}/${st.rem.inMinutes}/${st.awake.inMinutes}'}',
    );
  }
  return out.toString().trimRight();
}

String vitalsRows(LifeInputs i) {
  final v = i.vitals;
  if (v == null || !v.hasData) return '- no activity or heart data';
  final out = StringBuffer(
    'date | steps | active kcal | resting HR | avg HR | HRV ms | SpO2\n',
  );
  for (final d in v.days.where((d) => d.hasAny)) {
    out.writeln(
      '${dateLine.format(d.date)} | ${d.steps ?? '-'} | '
      '${d.activeKcal?.round() ?? '-'} | ${d.restingHr ?? '-'} | '
      '${d.avgHr ?? '-'} | ${d.hrvMs?.round() ?? '-'} | '
      '${d.spo2Avg?.toStringAsFixed(0) ?? '-'}',
    );
  }
  if (v.workouts.isNotEmpty) {
    out.writeln('\nWorkouts (date | type | minutes | kcal | km):');
    for (final w in v.workouts) {
      out.writeln(
        '${dateLine.format(w.start)} | ${w.label} | ${w.duration.inMinutes} | '
        '${w.kcal?.round() ?? '-'} | '
        '${w.distanceMeters == null ? '-' : (w.distanceMeters! / 1000).toStringAsFixed(1)}',
      );
    }
  }
  return out.toString().trimRight();
}

String weightRows(LifeInputs i) {
  final weights = i.vitals?.weights ?? const [];
  if (weights.isEmpty) return '- no weight readings';
  return [
    'date | kg',
    for (final w in weights)
      '${dateLine.format(w.time)} | ${w.kg.toStringAsFixed(1)}',
  ].join('\n');
}

String workRows(LifeInputs i) {
  final days = i.work.workDays;
  if (days.isEmpty) return '- no work visits found';
  final out = StringBuffer(
    'Scheduled arrival: ${i.work.scheduledArrivalLabel.isEmpty ? 'unknown' : i.work.scheduledArrivalLabel}'
    '${i.work.hasLateThreshold ? ', counted late after ${i.work.thresholdLabel}' : ''}\n'
    'date | arrival | minutes late\n',
  );
  for (final d in days) {
    out.writeln(
      '${dateLine.format(d.date)} | ${_time.format(d.arrivalTime)} | '
      '${d.delayMinutes ?? '-'}',
    );
  }
  return out.toString().trimRight();
}

String calendarRows(LifeInputs i) {
  final from = i.today.subtract(const Duration(days: 14));
  final to = i.today.add(const Duration(days: 35));
  final list = i.events.where((e) {
    final d = dayOf(e.start);
    return !d.isBefore(from) && !d.isAfter(to);
  }).toList()..sort((a, b) => a.start.compareTo(b.start));
  if (list.isEmpty) return '- no calendar events';
  final out = StringBuffer('date | time | title | tags\n');
  for (final e in list.take(120)) {
    final when = e.allDay
        ? 'all day'
        : '${_time.format(e.start.toLocal())}-${_time.format(e.end.toLocal())}';
    final tags = [
      if (e.isHoliday) 'holiday',
      if (e.location != null && e.location!.trim().isNotEmpty)
        'at ${e.location!.trim()}',
    ].join(', ');
    out.writeln('${dateLine.format(e.start)} | $when | ${e.title} | $tags');
  }
  return out.toString().trimRight();
}

String gameRows(LifeInputs i) {
  if (i.games.isEmpty) return '- no gaming sessions';
  final from = i.today.subtract(const Duration(days: 90));
  final perDay = <DateTime, Map<String, double>>{};
  for (final g in i.games) {
    final d = dayOf(g.sessionDate);
    if (d.isBefore(from)) continue;
    final games = perDay.putIfAbsent(d, () => {});
    games[g.name] = (games[g.name] ?? 0) + g.timePlayed.inMinutes / 60;
  }
  final days = perDay.keys.toList()..sort();
  return [
    'date | hours per game',
    for (final d in days)
      '${dateLine.format(d)} | ${perDay[d]!.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(1)}h').join(', ')}',
  ].join('\n');
}

String checklistRows(LifeInputs i) {
  final c = i.checklist;
  if (c == null) return '- no checklist';
  return [
    'Checklist: ${c.title}',
    'week | dates | items | done | marked failed',
    for (final w in c.weeks)
      'Week ${w.weekNumber} | ${shortDate.format(w.start)}-${shortDate.format(w.end)} '
          '| ${w.total} | ${w.done} | ${w.failed}',
  ].join('\n');
}

/// One row per day joining every domain, for finding links between them.
String patternRows(LifeInputs i, {int days = 60}) {
  final sleepByWake = {for (final n in i.nights) dayOf(n.wakeDate): n.session!};
  final stepsByDay = {
    for (final d in i.vitals?.days ?? const <DailyVitals>[]) dayOf(d.date): d,
  };
  final gamesByDay = <DateTime, double>{};
  for (final g in i.games) {
    final d = dayOf(g.sessionDate);
    gamesByDay[d] = (gamesByDay[d] ?? 0) + g.timePlayed.inMinutes / 60;
  }
  final eventHours = eventHoursByDay(i);
  final out = StringBuffer(
    'date | hours slept that night (waking this date) | bedtime | steps | '
    'resting HR | gaming h | calendar hours | spent\n',
  );
  var rows = 0;
  for (var back = days - 1; back >= 0; back--) {
    final d = i.today.subtract(Duration(days: back));
    final sleep = sleepByWake[d];
    final v = stepsByDay[d];
    final cells = [
      sleep == null ? '-' : (sleep.duration.inMinutes / 60).toStringAsFixed(2),
      sleep == null ? '-' : _time.format(sleep.startTime.toLocal()),
      v?.steps?.toString() ?? '-',
      v?.restingHr?.toString() ?? '-',
      gamesByDay[d]?.toStringAsFixed(1) ?? '0',
      eventHours[d]?.toStringAsFixed(1) ?? '0',
      i.dailySpend[d]?.round().toString() ?? '0',
    ];
    if (sleep == null && v == null && !gamesByDay.containsKey(d)) continue;
    rows++;
    out.writeln('${dateLine.format(d)} | ${cells.join(' | ')}');
  }
  return rows == 0 ? '- no overlapping data' : out.toString().trimRight();
}

/// Hours of timed (not all-day, not holiday) calendar events per day.
Map<DateTime, double> eventHoursByDay(LifeInputs i) {
  final out = <DateTime, double>{};
  for (final e in i.events) {
    if (e.allDay || e.isHoliday) continue;
    final hours = e.end.difference(e.start).inMinutes / 60;
    if (hours <= 0 || hours > 16) continue;
    final d = dayOf(e.start);
    out[d] = (out[d] ?? 0) + hours;
  }
  return out;
}
