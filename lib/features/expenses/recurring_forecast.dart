import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_insights.dart';

/// A bill or subscription expected to be charged again soon.
class UpcomingCharge {
  const UpcomingCharge({
    required this.label,
    required this.cadence,
    required this.amount,
    required this.expectedDate,
    required this.lastDate,
    required this.count,
    required this.declared,
  });

  final String label;

  /// `weekly`, `monthly`, `every 2 weeks`, or `about every 30 days`.
  final String cadence;

  /// Typical charge, positive.
  final double amount;
  final DateTime expectedDate;
  final DateTime lastDate;
  final int count;

  /// True when Cashew has a recurring rule for it, false when it was spotted
  /// from entries repeating at a steady gap.
  final bool declared;

  int daysUntil(DateTime now) => expectedDate.difference(_dayOf(now)).inDays;
  bool isOverdue(DateTime now) => daysUntil(now) < 0;
}

/// Charges due within [horizonDays] (or a few days late), soonest first.
///
/// Combines Cashew's own recurring rules with spending that repeats on its
/// own: the same title at least [minRepeats] times, at a steady gap, with a
/// similar amount. Fuel is left out because it has its own forecast.
List<UpcomingCharge> forecastRecurringCharges(
  Iterable<CashewTransaction> transactions, {
  DateTime? now,
  int horizonDays = 30,
  int minRepeats = 3,
}) {
  final today = _dayOf(now ?? DateTime.now());
  final all = transactions.toList();
  final out = <UpcomingCharge>[];
  final seen = <String>{};

  for (final s in detectRecurringSeries(all)) {
    if (s.typicalAmount >= 0 || _isSavings(s.category)) continue;
    if (!s.isActive(today)) continue;
    final next = _nextAfter(_dayOf(s.last), s.cadenceDays, today);
    if (next == null) continue;
    seen.add(_key(s.label));
    out.add(
      UpcomingCharge(
        label: s.label,
        cadence: s.cadence,
        amount: s.typicalAmount.abs(),
        expectedDate: next,
        lastDate: _dayOf(s.last),
        count: s.count,
        declared: true,
      ),
    );
  }

  final groups = <String, List<CashewTransaction>>{};
  for (final t in all) {
    if (!t.isRealExpense || t.type == CashewTxType.upcoming) continue;
    if (ExpensesSummary.isFuelExpense(t)) continue;
    final title = t.title?.trim() ?? '';
    if (title.isEmpty) continue;
    groups.putIfAbsent(_key(title), () => []).add(t);
  }

  for (final entry in groups.entries) {
    if (seen.contains(entry.key)) continue;
    final charge = _inferCharge(entry.value, today, minRepeats);
    if (charge != null) out.add(charge);
  }

  out.removeWhere((c) => c.daysUntil(today) > horizonDays);
  out.sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
  return out;
}

/// Whether [entries] (one title) repeat at a steady gap and amount, and when
/// the next one is due. Works on income too; amounts are taken as positive.
UpcomingCharge? inferRepeatingEntry(
  List<CashewTransaction> entries, {
  DateTime? now,
  int minRepeats = 3,
}) => _inferCharge(entries, _dayOf(now ?? DateTime.now()), minRepeats);

UpcomingCharge? _inferCharge(
  List<CashewTransaction> entries,
  DateTime today,
  int minRepeats,
) {
  // One charge per day, even when the title was entered twice.
  final byDay = <DateTime, double>{};
  for (final t in entries) {
    final day = _dayOf(t.date);
    byDay[day] = (byDay[day] ?? 0) + t.amount.abs();
  }
  if (byDay.length < minRepeats) return null;
  final days = byDay.keys.toList()..sort();
  // The most recent entries describe the habit; old history may predate it.
  final recent = days.length > 8 ? days.sublist(days.length - 8) : days;
  final gaps = <double>[
    for (var i = 1; i < recent.length; i++)
      recent[i].difference(recent[i - 1]).inDays.toDouble(),
  ];
  final gap = _median(gaps);
  if (gap < 6) return null;

  // Steady means every gap sits near the median: within a few days, or 15%.
  final tolerance = gap * 0.15 < 3 ? 3 : gap * 0.15;
  if (gaps.any((g) => (g - gap).abs() > tolerance)) return null;

  final amounts = [for (final d in recent) byDay[d]!];
  final typical = _median(amounts);
  if (typical <= 0) return null;
  // A bill, not a habit with a different cost each time.
  if (amounts.any((a) => (a - typical).abs() > typical * 0.5)) return null;

  final last = recent.last;
  final cadenceDays = gap.round();
  final monthly = (cadenceDays - 30).abs() <= 3;
  final next = monthly
      ? _nextMonthly(last, recent, today)
      : _nextAfter(last, cadenceDays, today);
  if (next == null) return null;

  return UpcomingCharge(
    label: entries.first.title!.trim(),
    cadence: _cadenceLabel(cadenceDays),
    amount: typical,
    expectedDate: next,
    lastDate: last,
    count: byDay.length,
    declared: false,
  );
}

/// Same day of the month as usual, clamped to short months. Null when that
/// date is more than a week past, i.e. the bill has lapsed.
DateTime? _nextMonthly(DateTime last, List<DateTime> recent, DateTime today) {
  final usualDay = _median([for (final d in recent) d.day.toDouble()]).round();
  final lastDayOfMonth = DateTime(last.year, last.month + 2, 0).day;
  final next = DateTime(
    last.year,
    last.month + 1,
    usualDay > lastDayOfMonth ? lastDayOfMonth : usualDay,
  );
  return today.difference(next).inDays > 7 ? null : next;
}

/// The next date at [gapDays] steps from [last] that isn't long past. Null
/// when the series looks lapsed: more than one cadence late.
DateTime? _nextAfter(DateTime last, int gapDays, DateTime today) {
  if (gapDays <= 0) return null;
  final next = last.add(Duration(days: gapDays));
  final late = today.difference(next).inDays;
  if (late > (gapDays < 14 ? gapDays : 14)) return null;
  return next;
}

String _cadenceLabel(int days) {
  if (days >= 6 && days <= 8) return 'weekly';
  if (days >= 13 && days <= 15) return 'every 2 weeks';
  if (days >= 27 && days <= 33) return 'monthly';
  return 'about every $days days';
}

bool _isSavings(String? category) =>
    category?.trim().toLowerCase() == 'savings';

String _key(String title) =>
    title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

DateTime _dayOf(DateTime d) {
  final local = d.toLocal();
  return DateTime(local.year, local.month, local.day);
}
