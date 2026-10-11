import 'package:personal/features/expenses/ai_ledger_text.dart';
import 'package:personal/features/expenses/recurring_forecast.dart';
import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';
import 'package:personal/features/forecasts/life_raw_data.dart';
import 'package:personal/features/forecasts/life_raw_money.dart';

/// Bills that rose against their history or are late.
LifeForecast? forecastBillAlerts(LifeInputs i) {
  final today = i.today;
  final alerts = <(String, bool)>[];
  // The same bills the Upcoming bills forecast finds: declared recurring
  // rules plus entries that repeat on their own.
  for (final c in forecastRecurringCharges(
    i.ledger,
    now: i.now,
    horizonDays: 45,
  )) {
    final key = labelKey(c.label);
    final entries = [
      for (final t in i.ledger)
        if (t.isRealExpense && labelKey(t.title ?? '') == key) t,
    ]..sort((a, b) => a.date.compareTo(b.date));
    if (entries.length < 3) continue;
    final last = entries.last.amount.abs();
    final before = median(
      entries.sublist(0, entries.length - 1).map((t) => t.amount.abs()),
    );
    if (before > 0 && (last - before).abs() / before >= 0.1) {
      alerts.add((
        '${c.label} ${last > before ? 'rose' : 'fell'} to '
            '${moneyLabel(last, i.currency)} (was ~${moneyLabel(before, i.currency)})',
        last > before,
      ));
    } else if (c.daysUntil(i.now) < -3) {
      alerts.add(('${c.label} looks late (${c.cadence})', true));
    }
  }
  if (alerts.isEmpty) return null;
  return LifeForecast(
    kind: LifeForecastKind.billAlerts,
    headline: '${alerts.length} to check',
    detail: alerts.first.$1,
    attention: alerts.any((a) => a.$2),
    notes: [for (final a in alerts.take(6)) a.$1],
    signature: fingerprint([alerts.length, alerts.first.$1]),
    rawData: billRows(i),
    question:
        'Review each recurring bill and its recent payments (today is '
        '${dateLine.format(today)}). Flag any whose latest amount changed '
        'noticeably, that is overdue against its usual gap, or that was '
        'paid twice. "headline" is how many need attention and "detail" the '
        'most important one.',
  );
}

/// Extra spending expected around the holidays ahead, from past holidays.
LifeForecast? forecastHolidaySpend(LifeInputs i) {
  final holidays = {
    for (final e in i.events)
      if (e.isHoliday) dayOf(e.start),
  };
  final past = holidays.where((d) => d.isBefore(i.today)).toList();
  final ahead =
      holidays
          .where(
            (d) => !d.isBefore(i.today) && d.difference(i.today).inDays <= 30,
          )
          .toList()
        ..sort();
  if (past.length < 2 || ahead.isEmpty) return null;
  final normal = <double>[];
  final start = i.today.subtract(const Duration(days: 75));
  for (var d = start; d.isBefore(i.today); d = d.add(const Duration(days: 1))) {
    if (!holidays.contains(d)) normal.add(i.dailySpend[d] ?? 0);
  }
  if (normal.length < 20) return null;
  final holidayAvg = mean(past.map((d) => i.dailySpend[d] ?? 0));
  final normalAvg = mean(normal);
  if (normalAvg <= 0) return null;
  final extraPerDay = holidayAvg - normalAvg;
  final extra = extraPerDay * ahead.length;
  return LifeForecast(
    kind: LifeForecastKind.holidaySpend,
    headline: '${extra >= 0 ? '+' : ''}${moneyLabel(extra, i.currency)}',
    detail:
        '${ahead.length} holiday day${ahead.length == 1 ? '' : 's'} from ${shortDate.format(ahead.first)}',
    date: ahead.first,
    attention: extra > normalAvg * 2,
    notes: [
      'On ${past.length} past holidays you spent ${moneyLabel(holidayAvg, i.currency)} a day against ${moneyLabel(normalAvg, i.currency)} on other days.',
    ],
    signature: fingerprint([ahead.length, extra]),
    rawData:
        'Holidays and events:\n${calendarRows(i)}\n\nDaily spending:\n${dailySpendRows(i.spending, i.now)}',
    question:
        'Estimate the extra spending the upcoming holidays will cause '
        '(today is ${dateLine.format(i.today)}). Compare spending on past '
        'holiday days and the days around them with ordinary days, then '
        'apply that to the holidays in the next 30 days. "value" is the '
        'extra amount over ordinary spending; "date" the first holiday.',
  );
}
