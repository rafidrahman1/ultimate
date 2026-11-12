import 'package:intl/intl.dart';

import 'package:personal/features/calendar/data/calendar_event.dart';
import 'package:personal/features/calendar/data/day_off.dart';
import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/health/data/vitals_models.dart';
import 'package:personal/features/journal/data/journal_models.dart';

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

/// Hours of phone use per local day (only days with usage).
Map<DateTime, double> screenHoursByDay(LifeInputs i) => {
  for (final e in i.screen.byDay.entries) e.key: e.value.inMinutes / 60,
};

String screenRows(LifeInputs i) {
  final days = screenHoursByDay(i);
  if (days.isEmpty) return '- no screen time recorded';
  final keys = days.keys.toList()..sort();
  final out = StringBuffer('date | screen hours\n');
  for (final d in keys) {
    out.writeln('${dateLine.format(d)} | ${days[d]!.toStringAsFixed(2)}');
  }
  final apps = i.screen.topApps
      .take(6)
      .map(
        (a) => '${a.label} ${(a.duration.inMinutes / 60).toStringAsFixed(1)}h',
      );
  out.writeln('\nTop apps overall: ${apps.join(', ')}');
  return out.toString().trimRight();
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
  final screen = screenHoursByDay(i);
  final out = StringBuffer(
    'date | hours slept that night (waking this date) | bedtime | steps | '
    'resting HR | gaming h | calendar hours | spent | screen h | '
    'phone pickups | phone put down | coffees | last coffee | last meal | '
    'mood 1-5 | energy 1-5 | stress 1-5\n',
  );
  final coffees = i.journal.countByDay(IntakeKind.caffeine);
  final lastCoffee = i.journal.lastMinutesByDay(IntakeKind.caffeine);
  final lastMeal = i.journal.lastMinutesByDay(IntakeKind.meal);
  var rows = 0;
  for (var back = days - 1; back >= 0; back--) {
    final d = i.today.subtract(Duration(days: back));
    final sleep = sleepByWake[d];
    final v = stepsByDay[d];
    final phone = i.phone.on(d);
    final phoneDown = phone != null && phone.complete
        ? phone.lastUseMinutes
        : null;
    final feel = i.journal.checkInOn(d);
    final cells = [
      sleep == null ? '-' : (sleep.duration.inMinutes / 60).toStringAsFixed(2),
      sleep == null ? '-' : _time.format(sleep.startTime.toLocal()),
      v?.steps?.toString() ?? '-',
      v?.restingHr?.toString() ?? '-',
      gamesByDay[d]?.toStringAsFixed(1) ?? '0',
      eventHours[d]?.toStringAsFixed(1) ?? '0',
      i.dailySpend[d]?.round().toString() ?? '0',
      screen[d]?.toStringAsFixed(1) ?? '-',
      phone?.pickups.toString() ?? '-',
      phoneDown == null ? '-' : clockLabel(phoneDown),
      coffees[d]?.toString() ?? '-',
      lastCoffee[d] == null ? '-' : clockLabel(lastCoffee[d]!),
      lastMeal[d] == null ? '-' : clockLabel(lastMeal[d]!),
      feel?.mood.toString() ?? '-',
      feel?.energy.toString() ?? '-',
      feel?.stress.toString() ?? '-',
    ];
    if (sleep == null &&
        v == null &&
        phone == null &&
        feel == null &&
        !coffees.containsKey(d) &&
        !lastMeal.containsKey(d) &&
        !gamesByDay.containsKey(d) &&
        !screen.containsKey(d)) {
      continue;
    }
    rows++;
    out.writeln('${dateLine.format(d)} | ${cells.join(' | ')}');
  }
  return rows == 0 ? '- no overlapping data' : out.toString().trimRight();
}

/// Days covered by public holidays in the calendar.
Set<DateTime> holidayDays(LifeInputs i) => holidayDaysOf(i.events);

/// True when [day] is a weekend day or a public holiday.
bool isDayOff(LifeInputs i, DateTime day, Set<DateTime> holidays) =>
    isDayOffOn(day, weekendDays: i.weekendDays, holidays: holidays);

/// Hours of timed (not all-day, not holiday) calendar events per day.
Map<DateTime, double> eventHoursByDay(LifeInputs i) =>
    eventHoursByDayOf(i.events);

/// [eventHoursByDay] for any list of events.
Map<DateTime, double> eventHoursByDayOf(Iterable<CalendarEvent> events) {
  final out = <DateTime, double>{};
  for (final e in events) {
    if (e.allDay || e.isHoliday) continue;
    final hours = e.end.difference(e.start).inMinutes / 60;
    if (hours <= 0 || hours > 16) continue;
    final d = dayOf(e.start);
    out[d] = (out[d] ?? 0) + hours;
  }
  return out;
}
