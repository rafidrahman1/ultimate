import 'package:intl/intl.dart';

import 'package:personal/features/expenses/ai_ledger_text.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/recurring_forecast.dart';
import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';

/// Raw ledger rows for the money forecasts.

String _monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);

/// Spending per top-level category for the last four months and this month
/// so far, from the spending ledger.
String categoryRows(LifeInputs i) {
  final months = <String, Map<String, double>>{};
  final from = DateTime(i.today.year, i.today.month - 4, 1);
  for (final t in i.spending) {
    if (!t.isRealExpense) continue;
    final d = dayOf(t.date);
    if (d.isBefore(from) || d.isAfter(i.today)) continue;
    final cats = months.putIfAbsent(_monthKey(d), () => {});
    final c = ExpensesSummary.categoryLabel(t);
    cats[c] = (cats[c] ?? 0) + t.amount.abs();
  }
  if (months.isEmpty) return '- no spending';
  final keys = months.keys.toList()..sort();
  final out = StringBuffer(
    'Spending per category per month. Today is day ${i.today.day} of '
    '${DateTime(i.today.year, i.today.month + 1, 0).day}; the last month listed is this month so '
    'far.\n',
  );
  for (final k in keys) {
    final cats = months[k]!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    out.writeln(
      '$k | ${cats.map((e) => '${e.key} ${e.value.round()}').join(', ')}',
    );
  }
  return out.toString().trimRight();
}

/// Total income and spending per month, and income entries.
String monthTotalsRows(LifeInputs i) {
  final income = <String, double>{};
  final spend = <String, double>{};
  final from = DateTime(i.today.year, i.today.month - 5, 1);
  for (final t in i.ledger) {
    final d = dayOf(t.date);
    if (d.isBefore(from) || d.isAfter(i.today)) continue;
    if (t.isRealIncome) {
      income[_monthKey(d)] = (income[_monthKey(d)] ?? 0) + t.amount.abs();
    }
  }
  for (final t in i.spending) {
    final d = dayOf(t.date);
    if (!t.isRealExpense || d.isBefore(from) || d.isAfter(i.today)) continue;
    spend[_monthKey(d)] = (spend[_monthKey(d)] ?? 0) + t.amount.abs();
  }
  final keys = {...income.keys, ...spend.keys}.toList()..sort();
  if (keys.isEmpty) return '- no income or spending';
  return [
    'month | income | spending (last row is this month so far)',
    for (final k in keys)
      '$k | ${income[k]?.round() ?? 0} | ${spend[k]?.round() ?? 0}',
    '',
    'Income entries:',
    incomeRows(i.ledger, i.now),
  ].join('\n');
}

/// Each recurring bill with its last payments.
String billRows(LifeInputs i) {
  final charges = forecastRecurringCharges(
    i.ledger,
    now: i.now,
    horizonDays: 45,
  );
  if (charges.isEmpty) return '- no recurring bills found';
  final out = StringBuffer();
  for (final c in charges.take(15)) {
    final key = labelKey(c.label);
    out
      ..writeln(
        '${c.label} (${c.cadence}, usually ${c.amount.round()}, '
        'next expected ${dateLine.format(c.expectedDate)}):',
      )
      ..writeln(
        entryRows(
          i.ledger,
          (t) =>
              t.isRealExpense &&
              labelKey(t.title ?? '').isNotEmpty &&
              labelKey(t.title ?? '') == key,
          limit: 8,
        ),
      );
  }
  return out.toString().trimRight();
}

String labelKey(String label) =>
    label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Fuel entries with the price per litre when the note gives one.
String fuelPriceRows(LifeInputs i) {
  final rows = <String>['date | price per litre | amount | note'];
  final day = DateFormat('yyyy-MM-dd');
  final fuel = [
    for (final t in i.ledger)
      if (t.isRealExpense && ExpensesSummary.isFuelExpense(t)) t,
  ]..sort((a, b) => a.date.compareTo(b.date));
  for (final t in fuel.length > 40 ? fuel.sublist(fuel.length - 40) : fuel) {
    final rate = ExpensesSummary.fuelRatePerLitreFromDescription(t);
    rows.add(
      '${day.format(dayOf(t.date))} | ${rate?.toStringAsFixed(0) ?? '-'} | '
      '${t.amount.abs().round()} | ${(t.note ?? '').replaceAll('\n', ' ')}',
    );
  }
  return rows.length == 1 ? '- no fuel entries' : rows.join('\n');
}
