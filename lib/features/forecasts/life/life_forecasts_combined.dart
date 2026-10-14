import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/forecasts/life/life_raw_data.dart';
import 'package:personal/features/health/data/vitals_models.dart';

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
        'You finish only ${(weak.value * 100).round()}% of these, while '
        '${strong.key} goals get done ${(strong.value * 100).round()}% of the time.',
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

/// The coming day that suits something demanding.
///
/// Workdays are compared with workdays and days off (weekends and public
/// holidays) with days off, so a holiday Wednesday is not averaged in with
/// ordinary Wednesdays. A free day off gets a small lift for having no work.
LifeForecast? forecastBestDay(LifeInputs i) {
  final holidays = holidayDays(i);
  // Keyed by day type (0 workday, 1 day off) then weekday.
  final sleepBy = <int, Map<int, List<double>>>{0: {}, 1: {}};
  for (final n in i.nights) {
    final s = n.session;
    if (s == null) continue;
    final t = isDayOff(i, n.wakeDate, holidays) ? 1 : 0;
    sleepBy[t]!
        .putIfAbsent(n.wakeDate.weekday, () => [])
        .add(s.duration.inMinutes / 60);
  }
  final stepBy = <int, Map<int, List<double>>>{0: {}, 1: {}};
  for (final d in i.vitals?.days ?? const <DailyVitals>[]) {
    if (d.steps != null) {
      final t = isDayOff(i, d.date, holidays) ? 1 : 0;
      stepBy[t]!.putIfAbsent(d.date.weekday, () => []).add(d.steps! / 1000.0);
    }
  }
  final haveSleep = sleepBy[0]!.length + sleepBy[1]!.length;
  final haveSteps = stepBy[0]!.length + stepBy[1]!.length;
  if (haveSleep < 4 && haveSteps < 4) return null;
  final hours = eventHoursByDay(i);
  final dates = [for (var d = 1; d <= 14; d++) i.today.add(Duration(days: d))];
  // Typical value for a day type: the weekday's own average if there is one,
  // else the average of that day type.
  double? typical(Map<int, List<double>> byWeekday, int weekday) {
    final own = byWeekday[weekday];
    if (own != null && own.isNotEmpty) return mean(own);
    final all = [for (final v in byWeekday.values) ...v];
    return all.isEmpty ? null : mean(all);
  }

  double z(double v, Iterable<double> all) {
    final sd = stdDev(all);
    return sd == 0 ? 0 : (v - mean(all)) / sd;
  }

  final sleepVals = {
    for (var t = 0; t < 2; t++)
      t: [for (final e in sleepBy[t]!.entries) mean(e.value)],
  };
  final stepVals = {
    for (var t = 0; t < 2; t++)
      t: [for (final e in stepBy[t]!.entries) mean(e.value)],
  };
  final load = [for (final d in dates) hours[d] ?? 0.0];
  DateTime? best;
  var bestScore = -1e9;
  var bestOff = false;
  for (var k = 0; k < dates.length; k++) {
    final d = dates[k];
    final off = isDayOff(i, d, holidays);
    final t = off ? 1 : 0;
    var score = -z(load[k], load);
    final sleep = typical(sleepBy[t]!, d.weekday);
    if (sleep != null && sleepVals[t]!.length >= 2) {
      score += z(sleep, sleepVals[t]!);
    }
    final steps = typical(stepBy[t]!, d.weekday);
    if (steps != null && stepVals[t]!.length >= 2) {
      score += z(steps, stepVals[t]!);
    }
    if (off && load[k] == 0) score += 0.5;
    if (score > bestScore) {
      bestScore = score;
      best = d;
      bestOff = off;
    }
  }
  if (best == null) return null;
  final sleepHere = typical(sleepBy[bestOff ? 1 : 0]!, best.weekday);
  final kind = holidays.contains(best)
      ? 'holiday'
      : bestOff
      ? 'day off'
      : 'workday';
  return LifeForecast(
    kind: LifeForecastKind.bestDay,
    headline: '${weekdayShort(best)} ${shortDate.format(best)}',
    detail:
        'Your best day for something demanding, a $kind: '
        '${(hours[best] ?? 0) == 0 ? 'nothing booked' : '${(hours[best] ?? 0).toStringAsFixed(1)} hours booked'}'
        '${sleepHere == null ? '' : ' and you usually sleep ${hoursLabel(sleepHere)} before it'}.',
    date: best,
    notes: [
      'Scores each of the next 14 days: lighter calendar, better sleep and more activity raise it. Workdays are compared with workdays, and weekends and public holidays with days off.',
      'Days off: ${i.weekendDays.isEmpty ? 'Fri and Sat (default)' : i.weekendDays.map((d) => weekdayShort(DateTime(2024, 1, d))).join(', ')}'
          '${holidays.isEmpty ? '' : ', plus ${holidays.where((h) => !h.isBefore(i.today)).length} upcoming holiday days from the calendar'}.',
    ],
    signature: fingerprint([best, bestScore]),
    rawData:
        '${patternRows(i)}\n\nCalendar:\n${calendarRows(i)}\n\n'
        'Next 14 days by type:\n'
        '${dates.map((d) => '${dateLine.format(d)} ${holidays.contains(d)
            ? 'holiday'
            : isDayOff(i, d, holidays)
            ? 'weekend/day off'
            : 'workday'}').join('\n')}',
    question:
        'Pick the best day in the next 14 days from ${dateLine.format(i.today)} '
        'for something demanding. Use the day types listed: compare workdays '
        'with workdays and weekends or holidays with days off, prefer days '
        'with a light calendar where I usually sleep well and move more, and '
        'favour a free day off over a workday. '
        '"headline" is the day and "date" the date.',
  );
}
