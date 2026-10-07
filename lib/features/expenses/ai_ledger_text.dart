import 'package:intl/intl.dart';

import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/location/timeline_activity.dart';

/// Raw rows from the expense ledger and riding log, as text an AI can
/// calculate from. These carry the data itself, not computed forecasts, so the
/// model can do its own arithmetic.
final _day = DateFormat('yyyy-MM-dd (EEE)');

DateTime _dayOf(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

String _clean(String? text, [int max = 60]) {
  final t = (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= max ? t : '${t.substring(0, max - 1)}…';
}

/// Real spending per day for the last [days] days. Days not listed had none.
String dailySpendRows(
  Iterable<CashewTransaction> transactions,
  DateTime now, {
  int days = 120,
}) {
  final today = _dayOf(now);
  final from = today.subtract(Duration(days: days));
  final totals = <DateTime, double>{};
  for (final t in transactions) {
    if (!t.isRealExpense) continue;
    final d = _dayOf(t.date);
    if (d.isBefore(from) || d.isAfter(today)) continue;
    totals[d] = (totals[d] ?? 0) + t.amount.abs();
  }
  if (totals.isEmpty) return '- no spending';
  final keys = totals.keys.toList()..sort();
  return [
    'date | total spent (days not listed had no spending)',
    for (final d in keys) '${_day.format(d)} | ${totals[d]!.round()}',
  ].join('\n');
}

/// Income entries from the last [months] months.
String incomeRows(
  Iterable<CashewTransaction> transactions,
  DateTime now, {
  int months = 12,
  int limit = 60,
}) {
  final from = DateTime(now.year, now.month - months, now.day);
  final rows = [
    for (final t in transactions)
      if (t.isRealIncome && !t.date.toLocal().isBefore(from)) t,
  ]..sort((a, b) => a.date.compareTo(b.date));
  if (rows.isEmpty) return '- no income entries';
  final latest = rows.length > limit ? rows.sublist(rows.length - limit) : rows;
  return [
    'date | title | amount | category',
    for (final t in latest)
      '${_day.format(_dayOf(t.date))} | ${_clean(t.displayTitle)} | '
          '${t.amount.abs().round()} | ${_clean(t.category, 30)}',
  ].join('\n');
}

/// Entries matching [test], oldest first, newest [limit] kept.
String entryRows(
  Iterable<CashewTransaction> transactions,
  bool Function(CashewTransaction) test, {
  int limit = 60,
}) {
  final rows = [
    for (final t in transactions)
      if (test(t)) t,
  ]..sort((a, b) => a.date.compareTo(b.date));
  if (rows.isEmpty) return '- none';
  final latest = rows.length > limit ? rows.sublist(rows.length - limit) : rows;
  return [
    'date | title | amount | note',
    for (final t in latest)
      '${_day.format(_dayOf(t.date))} | ${_clean(t.displayTitle)} | '
          '${t.amount.abs().round()} | ${_clean(t.note, 80)}',
  ].join('\n');
}

/// Motorcycle km per day for the last [days] days. Days not listed had none.
String dailyKmRows(
  Iterable<TimelineActivity> activities,
  DateTime now, {
  int days = 120,
}) {
  final today = _dayOf(now);
  final from = today.subtract(Duration(days: days));
  final km = <DateTime, double>{};
  for (final a in activities) {
    if (!a.isMotorcycling || a.distanceMeters <= 0) continue;
    final d = _dayOf(a.startTime);
    if (d.isBefore(from) || d.isAfter(today)) continue;
    km[d] = (km[d] ?? 0) + a.distanceMeters / 1000;
  }
  if (km.isEmpty) return '- no riding recorded';
  final keys = km.keys.toList()..sort();
  return [
    'date | km ridden (days not listed had no riding)',
    for (final d in keys) '${_day.format(d)} | ${km[d]!.toStringAsFixed(1)}',
  ].join('\n');
}
