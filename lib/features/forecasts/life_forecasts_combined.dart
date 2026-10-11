import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';
import 'package:personal/features/forecasts/life_raw_data.dart';
import 'package:personal/features/health/vitals_models.dart';

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
