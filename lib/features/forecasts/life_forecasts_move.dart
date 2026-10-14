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

/// Linear-interpolated [q] quantile (0..1) of [values].
double _quantile(List<double> values, double q) {
  final sorted = [...values]..sort();
  final pos = (sorted.length - 1) * q;
  final lo = pos.floor();
  final hi = pos.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

class _LeavePlan {
  const _LeavePlan({
    required this.pool,
    required this.sameDay,
    required this.typical,
    required this.safe,
    required this.covered,
    required this.target,
    required this.leaveBy,
    required this.usualLeave,
  });

  final List<CommuteSample> pool;
  final int sameDay;
  final double typical;
  final double safe;
  final int covered;
  final int target;
  final int leaveBy;
  final double usualLeave;
}

/// When to leave on [day]: the arrival target minus a trip time that covers
/// most past trips on that weekday (all trips when there are few).
_LeavePlan _planFor(LifeInputs i, List<CommuteSample> samples, DateTime day) {
  int mins(CommuteSample s) => s.arrived.difference(s.left).inMinutes;
  final sameDay = [
    for (final s in samples)
      if (s.day.weekday == day.weekday) s,
  ];
  final pool = sameDay.length >= 3 ? sameDay : samples;
  final durations = [for (final s in pool) mins(s).toDouble()];
  final safe = _quantile(durations, 0.8);
  final scheduled = i.work.scheduledArrivalTime;
  final target = scheduled != null
      ? scheduled.hour * 60 + scheduled.minute
      : median([
          for (final s in pool) minutesOfDay(s.arrived).toDouble(),
        ]).round();
  return _LeavePlan(
    pool: pool,
    sameDay: sameDay.length,
    typical: median(durations),
    safe: safe,
    covered: durations.where((d) => d <= safe).length,
    target: target,
    // Round down to 5 minutes so the advice is never later than the maths.
    leaveBy: ((target - safe) / 5).floor() * 5,
    usualLeave: mean([for (final s in pool) minutesOfDay(s.left)]),
  );
}

/// When to leave home for the next working day: the work start (or your usual
/// arrival) minus a travel time that covers most of the last weeks' trips.
LifeForecast? forecastCommute(LifeInputs i) {
  final cutoff = i.today.subtract(const Duration(days: 56));
  final samples = [
    for (final s in commuteSamples(i))
      if (!s.day.isBefore(cutoff)) s,
  ];
  if (samples.length < 5) return null;
  // Next day you usually commute: tomorrow onward.
  final usual = <int, int>{};
  for (final s in samples) {
    usual.update(s.day.weekday, (n) => n + 1, ifAbsent: () => 1);
  }
  // Weekends and public holidays are not commuting days, even on a weekday
  // you usually go in.
  final holidays = holidayDays(i);
  bool commutes(DateTime d) =>
      (usual[d.weekday] ?? 0) >= 2 && !isDayOff(i, d, holidays);
  var next = i.today.add(const Duration(days: 1));
  for (var guard = 0; guard < 15 && !commutes(next); guard++) {
    next = next.add(const Duration(days: 1));
  }
  if (!commutes(next)) return null;

  final plan = _planFor(i, samples, next);
  final sameDay = plan.sameDay;
  final pool = plan.pool;
  final typical = plan.typical;
  final safe = plan.safe;
  final covered = plan.covered;
  final scheduled = i.work.scheduledArrivalTime;
  final target = plan.target;
  final leaveBy = plan.leaveBy;
  final usualLeave = plan.usualLeave;
  final earlier = usualLeave - leaveBy;
  final day = weekdayShort(next);

  return LifeForecast(
    kind: LifeForecastKind.commute,
    headline: clockLabel(leaveBy),
    detail:
        'Leave by this time on $day to reach work by ${clockLabel(target)}, '
        'allowing a ${safe.round()} minute trip'
        '${earlier >= 5 ? ' (${earlier.round()} minutes earlier than you usually leave)' : ''}.',
    date: next,
    leavePlan: {
      for (var k = 1; k <= 14; k++)
        if (commutes(i.today.add(Duration(days: k))))
          i.today.add(Duration(days: k)): _planFor(
            i,
            samples,
            i.today.add(Duration(days: k)),
          ).leaveBy,
    },
    attention: earlier >= 10,
    notes: [
      'Based on ${pool.length} ${sameDay >= 3 ? '$day trips' : 'trips'} from the last ${samples.length} commutes over 8 weeks.',
      'Typical trip ${typical.round()} min; leaving for a ${safe.round()} min trip would have got you there on time on $covered of ${pool.length} of them.',
      scheduled != null
          ? 'Target is your work start, ${clockLabel(target)}.'
          : 'No work hours set, so the target is your usual $day arrival, ${clockLabel(target)}.',
      'You usually leave at ${clockLabel(usualLeave)}.',
    ],
    signature: fingerprint([samples.length, samples.last.day, safe, target]),
    rawData:
        '${commuteRows(i)}\n\nWork start: ${scheduled == null ? 'unknown' : clockLabel(target)}\n\nCalendar:\n${calendarRows(i)}',
    question:
        'Tell me the best time to leave home for work on '
        '${dateLine.format(next)} (today is ${dateLine.format(i.today)}). '
        'Use only the last 8 weeks of trips: weekday differences, recent '
        'drift, outliers, and any early calendar event that day. Pick a '
        'departure that gets me to work on time on about 8 of 10 days. '
        '"value" is the departure as minutes after midnight; "headline" is '
        'the departure time as HH:mm.',
  );
}
