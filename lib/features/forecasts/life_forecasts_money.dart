import 'package:personal/features/expenses/ai_ledger_text.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/recurring_forecast.dart';
import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';
import 'package:personal/features/forecasts/life_raw_data.dart';
import 'package:personal/features/forecasts/life_raw_money.dart';

/// Per-month totals of [t] by [key], for full months before this one.
Map<String, double> _perMonth(
  Iterable<CashewTransaction> list,
  DateTime today,
  bool Function(CashewTransaction) test,
  double Function(CashewTransaction) value,
) {
  final out = <String, double>{};
  for (final t in list) {
    if (!test(t)) continue;
    final d = dayOf(t.date);
    if (d.isAfter(today)) continue;
    final k = '${d.year}-${d.month}';
    out[k] = (out[k] ?? 0) + value(t);
  }
  return out;
}

/// The spending category most likely to end the month over its usual level.
LifeForecast? forecastCategories(LifeInputs i) {
  final today = i.today;
  final dim = DateTime(today.year, today.month + 1, 0).day;
  final thisKey = '${today.year}-${today.month}';
  final prior = [
    for (var m = 1; m <= 3; m++)
      '${DateTime(today.year, today.month - m).year}-${DateTime(today.year, today.month - m).month}',
  ];
  final byCat = <String, Map<String, double>>{};
  for (final t in i.spending) {
    if (!t.isRealExpense) continue;
    final d = dayOf(t.date);
    if (d.isAfter(today)) continue;
    final k = '${d.year}-${d.month}';
    if (k != thisKey && !prior.contains(k)) continue;
    final cats = byCat.putIfAbsent(ExpensesSummary.categoryLabel(t), () => {});
    cats[k] = (cats[k] ?? 0) + t.amount.abs();
  }
  final monthsWithData = {
    for (final c in byCat.values) ...c.keys.where(prior.contains),
  };
  if (monthsWithData.length < 2) return null;

  final totalTypical = byCat.values.fold<double>(
    0,
    (a, c) => a + mean(prior.map((k) => c[k] ?? 0)),
  );
  String? worst;
  var worstOver = 0.0;
  double worstTypical = 0;
  double worstProjected = 0;
  double worstSpent = 0;
  for (final e in byCat.entries) {
    final typical = mean(prior.map((k) => e.value[k] ?? 0));
    if (typical < totalTypical * 0.04) continue;
    final spent = e.value[thisKey] ?? 0;
    final projected = spent + typical / dim * (dim - today.day);
    final over = projected - typical;
    if (over > worstOver) {
      worstOver = over;
      worst = e.key;
      worstTypical = typical;
      worstProjected = projected;
      worstSpent = spent;
    }
  }
  if (worst == null || worstOver < worstTypical * 0.05) return null;

  final rate = worstSpent / today.day;
  DateTime? crossing;
  if (worstSpent < worstTypical && rate > 0) {
    final days = ((worstTypical - worstSpent) / rate).ceil();
    final d = today.add(Duration(days: days));
    if (d.month == today.month) crossing = d;
  }
  final pct = (worstOver / worstTypical * 100).round();
  return LifeForecast(
    kind: LifeForecastKind.categories,
    headline: worst,
    detail:
        '~${moneyLabel(worstProjected, i.currency)} vs usual '
        '${moneyLabel(worstTypical, i.currency)} (+$pct%)',
    date: crossing,
    attention: pct >= 20,
    notes: [
      '${moneyLabel(worstSpent, i.currency)} spent on $worst so far this month.',
      'Usual is the average of the last 3 months; the rest of the month is projected at that daily rate.',
      if (crossing != null)
        'At this month\'s pace it passes its usual level around ${shortDate.format(crossing)}.',
    ],
    signature: fingerprint([worst, worstSpent, today.day]),
    rawData: categoryRows(i),
    question:
        'Find which spending category is most likely to finish this month '
        'well above its usual level (today is ${dateLine.format(today)}). '
        'Work out each category\'s usual month from the earlier months, its '
        'pace so far, and spending that tends to land late in the month. '
        '"headline" is the category, "value" the projected month total and '
        '"date" the day it passes its usual level, if it will.',
  );
}

/// Income minus spending by month-end.
LifeForecast? forecastNetMonth(LifeInputs i) {
  final today = i.today;
  final dim = DateTime(today.year, today.month + 1, 0).day;
  final thisKey = '${today.year}-${today.month}';
  final income = _perMonth(
    i.ledger,
    today,
    (t) => t.isRealIncome,
    (t) => t.amount.abs(),
  );
  final spend = _perMonth(
    i.spending,
    today,
    (t) => t.isRealExpense,
    (t) => t.amount.abs(),
  );
  final prior = [
    for (var m = 1; m <= 3; m++)
      '${DateTime(today.year, today.month - m).year}-${DateTime(today.year, today.month - m).month}',
  ];
  final spendPrior = [for (final k in prior) ?spend[k]];
  if (spendPrior.length < 2) return null;
  final incomePrior = [for (final k in prior) ?income[k]];
  final typicalSpend = mean(spendPrior);
  final spentNow = spend[thisKey] ?? 0;
  final projectedSpend = spentNow + typicalSpend / dim * (dim - today.day);
  final receivedNow = income[thisKey] ?? 0;
  final typicalIncome = incomePrior.isEmpty ? 0.0 : median(incomePrior);
  final expectedIncome = receivedNow > typicalIncome
      ? receivedNow
      : typicalIncome;
  if (expectedIncome <= 0) return null;
  final net = expectedIncome - projectedSpend;
  return LifeForecast(
    kind: LifeForecastKind.netMonth,
    headline: '${net >= 0 ? '+' : ''}${moneyLabel(net, i.currency)}',
    detail:
        'Income ~${moneyLabel(expectedIncome, i.currency)} · spend '
        '~${moneyLabel(projectedSpend, i.currency)}',
    attention: net < 0,
    notes: [
      'Income is the larger of what has arrived (${moneyLabel(receivedNow, i.currency)}) and a typical month (${moneyLabel(typicalIncome, i.currency)}).',
      'Spending is ${moneyLabel(spentNow, i.currency)} so far plus a typical day for each day left.',
    ],
    signature: fingerprint([net, today.day]),
    rawData: monthTotalsRows(i),
    question:
        'Predict how much I will have left (income minus spending) at the '
        'end of this month (today is ${dateLine.format(today)}). Judge '
        'whether income still to arrive will really come, using the income '
        'entries, and project spending from the monthly totals. "value" is '
        'the net amount, negative if I overspend.',
  );
}

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

/// Fuel price a month out, from the prices noted on refuel entries.
LifeForecast? forecastFuelPrice(LifeInputs i) {
  final rates = <(DateTime, double)>[];
  for (final t in i.ledger) {
    if (!t.isRealExpense || !ExpensesSummary.isFuelExpense(t)) continue;
    final r = ExpensesSummary.fuelRatePerLitreFromDescription(t);
    if (r != null) rates.add((dayOf(t.date), r));
  }
  rates.sort((a, b) => a.$1.compareTo(b.$1));
  if (rates.length < 4) return null;
  final first = rates.first.$1;
  final xs = [for (final r in rates) r.$1.difference(first).inDays.toDouble()];
  final ys = [for (final r in rates) r.$2];
  final perDay = slope(xs, ys);
  if (perDay == null || xs.last - xs.first < 20) return null;
  final now = ys.last;
  final in30 = now + perDay * 30;
  final rising = perDay * 30 >= now * 0.02;
  return LifeForecast(
    kind: LifeForecastKind.fuelPrice,
    headline: '~${in30.toStringAsFixed(0)}/L',
    detail:
        'in 30 days · ${signed(perDay * 30, digits: 0)}/month · now ${now.toStringAsFixed(0)}',
    attention: rising,
    notes: [
      'Straight-line fit through ${rates.length} refuels that noted a price.',
    ],
    signature: fingerprint([rates.length, rates.last.$1, now]),
    rawData: fuelPriceRows(i),
    question:
        'Predict the fuel price per litre 30 days from today '
        '(${dateLine.format(i.today)}). Read each price from the price '
        'column or the note, fit the trend yourself and allow for step '
        'changes. "value" is the price per litre.',
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
