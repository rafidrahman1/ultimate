import 'package:personal/features/expenses/cashew_transaction.dart';

/// One calendar month of money in and out, for trend charts.
class MonthlyExpenseRow {
  const MonthlyExpenseRow({
    required this.month,
    required this.spend,
    required this.income,
    required this.saved,
    required this.withdrawn,
    required this.corrections,
    required this.correctionNet,
  });

  final DateTime month;

  /// Real spending: no savings, loans or balance fixes.
  final double spend;

  /// Real income (the `Cash In` category).
  final double income;

  /// Moved into savings.
  final double saved;

  /// Taken back out of savings.
  final double withdrawn;

  /// Balance-correction entries, a sign of money that wasn't recorded.
  final int corrections;
  final double correctionNet;

  double get netSaved => saved - withdrawn;
}

/// Every month from the first to the last transaction, oldest first, with
/// empty months included so charts stay continuous.
List<MonthlyExpenseRow> buildMonthlyExpenseHistory(ExpensesSummary summary) {
  if (summary.transactions.isEmpty) return const [];

  int key(DateTime d) => d.year * 12 + (d.month - 1);
  final spend = <int, double>{};
  final income = <int, double>{};
  final saved = <int, double>{};
  final withdrawn = <int, double>{};
  final corrections = <int, int>{};
  final correctionNet = <int, double>{};

  for (final t in summary.transactions) {
    final local = t.date.toLocal();
    final k = key(local);
    if (t.isRealExpense) spend[k] = (spend[k] ?? 0) + t.amount.abs();
    if (t.isRealIncome) income[k] = (income[k] ?? 0) + t.amount.abs();
    if (t.savedAmount > 0) saved[k] = (saved[k] ?? 0) + t.savedAmount;
    if (t.withdrawnAmount > 0) {
      withdrawn[k] = (withdrawn[k] ?? 0) + t.withdrawnAmount;
    }
    if (t.isBalanceCorrection) {
      corrections[k] = (corrections[k] ?? 0) + 1;
      correctionNet[k] = (correctionNet[k] ?? 0) + t.amount;
    }
  }

  final keys = summary.transactions.map((t) => key(t.date.toLocal()));
  final first = keys.reduce((a, b) => a < b ? a : b);
  final last = keys.reduce((a, b) => a > b ? a : b);

  return [
    for (var k = first; k <= last; k++)
      MonthlyExpenseRow(
        month: DateTime(k ~/ 12, k % 12 + 1),
        spend: spend[k] ?? 0,
        income: income[k] ?? 0,
        saved: saved[k] ?? 0,
        withdrawn: withdrawn[k] ?? 0,
        corrections: corrections[k] ?? 0,
        correctionNet: correctionNet[k] ?? 0,
      ),
  ];
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// What a normal month looks like: the median of recent complete months that
/// had any spending. Null with fewer than two such months.
double? typicalMonthlySpend(
  List<MonthlyExpenseRow> history, {
  DateTime? now,
  int months = 6,
}) {
  final today = now ?? DateTime.now();
  final complete = history
      .where(
        (m) =>
            (m.month.year < today.year ||
                (m.month.year == today.year && m.month.month < today.month)) &&
            m.spend > 0,
      )
      .toList();
  if (complete.length < 2) return null;
  final recent = complete.length > months
      ? complete.sublist(complete.length - months)
      : complete;
  return _median([for (final m in recent) m.spend]);
}

/// Where this month is heading, from what's spent so far plus a normal day's
/// spending for the days left. A single large purchase doesn't distort it the
/// way a straight-line extrapolation would.
class MonthProjection {
  const MonthProjection({
    required this.spentSoFar,
    required this.projected,
    required this.typicalMonth,
    required this.daysElapsed,
    required this.daysInMonth,
  });

  final double spentSoFar;
  final double projected;
  final double typicalMonth;
  final int daysElapsed;
  final int daysInMonth;
}

MonthProjection? projectMonth({
  required double spentSoFar,
  required List<MonthlyExpenseRow> history,
  required DateTime periodStart,
  required DateTime now,
}) {
  // Only meaningful while the month is still running.
  if (now.year != periodStart.year || now.month != periodStart.month) {
    return null;
  }
  final typical = typicalMonthlySpend(history, now: now);
  if (typical == null) return null;
  final days = DateTime(now.year, now.month + 1, 0).day;
  final remaining = days - now.day;
  final projected = spentSoFar + typical / days * remaining;
  return MonthProjection(
    spentSoFar: spentSoFar,
    projected: projected,
    typicalMonth: typical,
    daysElapsed: now.day,
    daysInMonth: days,
  );
}

// ── Recurring ────────────────────────────────────────────────────────────

/// A repeating entry (weekly savings, a subscription).
class RecurringSeries {
  const RecurringSeries({
    required this.label,
    required this.cadence,
    required this.cadenceDays,
    required this.typicalAmount,
    required this.count,
    required this.first,
    required this.last,
    required this.total,
    this.category,
  });

  final String label;

  /// `weekly`, `monthly`, `every 2 weeks`.
  final String cadence;
  final int cadenceDays;

  /// Signed: negative is money out.
  final double typicalAmount;
  final int count;
  final DateTime first;
  final DateTime last;
  final String? category;

  /// Still running: its last entry is within two cadences of [now].
  bool isActive(DateTime now) =>
      now.difference(last).inDays <= cadenceDays * 2 + 3;

  /// Sum of every entry in the series, signed.
  final double total;
}

final _recurrence = RegExp(
  r'every\s+(\d+)\s+(day|week|month|year)',
  caseSensitive: false,
);

({String label, int days})? parseRecurrence(String? raw) {
  if (raw == null) return null;
  final match = _recurrence.firstMatch(raw);
  if (match == null) return null;
  final n = int.parse(match.group(1)!);
  final unit = match.group(2)!.toLowerCase();
  final perUnit = switch (unit) {
    'day' => 1,
    'week' => 7,
    'month' => 30,
    _ => 365,
  };
  final adjective = switch (unit) {
    'day' => 'daily',
    'week' => 'weekly',
    'month' => 'monthly',
    _ => 'yearly',
  };
  return (label: n == 1 ? adjective : 'every $n ${unit}s', days: n * perUnit);
}

/// Groups recurring entries by title and rule (the amount can vary). Most
/// recent first.
List<RecurringSeries> detectRecurringSeries(
  Iterable<CashewTransaction> transactions,
) {
  final groups = <String, List<CashewTransaction>>{};
  for (final t in transactions) {
    if (t.type != CashewTxType.repetitive) continue;
    if (parseRecurrence(t.recurrence) == null) continue;
    final title = t.title?.trim().toLowerCase() ?? '';
    final key = '$title|${t.recurrence!.toLowerCase()}';
    groups.putIfAbsent(key, () => []).add(t);
  }

  final series = <RecurringSeries>[];
  for (final entries in groups.values) {
    entries.sort((a, b) => a.date.compareTo(b.date));
    final rule = parseRecurrence(entries.first.recurrence)!;
    final title = entries.first.title?.trim() ?? '';
    final category = entries.first.category?.trim();
    series.add(
      RecurringSeries(
        label: title.isNotEmpty
            ? title
            : (category != null && category.isNotEmpty
                  ? '$category (untitled)'
                  : 'Recurring'),
        cadence: rule.label,
        cadenceDays: rule.days,
        typicalAmount: _median([for (final e in entries) e.amount]),
        count: entries.length,
        first: entries.first.date,
        last: entries.last.date,
        total: entries.fold<double>(0, (sum, e) => sum + e.amount),
        category: category,
      ),
    );
  }
  series.sort((a, b) => b.last.compareTo(a.last));
  return series;
}

// ── Period insights ──────────────────────────────────────────────────────

class SavingsStats {
  const SavingsStats({
    required this.saved,
    required this.withdrawn,
    required this.deposits,
    this.rate,
  });

  static const empty = SavingsStats(saved: 0, withdrawn: 0, deposits: 0);

  final double saved;
  final double withdrawn;
  final int deposits;

  /// Net saved as a share of income. Null with no income.
  final double? rate;

  double get net => saved - withdrawn;
  bool get hasActivity => saved > 0 || withdrawn > 0;
}

class LoanSummary {
  const LoanSummary({
    required this.owedToYou,
    required this.youOwe,
    required this.lentCount,
    required this.borrowedCount,
    required this.items,
  });

  static const empty = LoanSummary(
    owedToYou: 0,
    youOwe: 0,
    lentCount: 0,
    borrowedCount: 0,
    items: [],
  );

  final double owedToYou;
  final double youOwe;
  final int lentCount;
  final int borrowedCount;

  /// Oldest first.
  final List<CashewLoan> items;

  bool get hasAny => items.isNotEmpty;

  /// Positive when you are owed more than you owe.
  double get net => owedToYou - youOwe;

  DateTime? get oldest => items.isEmpty ? null : items.first.date;
}

LoanSummary summarizeLoans(List<CashewLoan> loans) {
  if (loans.isEmpty) return LoanSummary.empty;
  final sorted = [...loans]..sort((a, b) => a.date.compareTo(b.date));
  var owed = 0.0;
  var owe = 0.0;
  var lent = 0;
  var borrowed = 0;
  for (final loan in sorted) {
    if (loan.owedToYou) {
      owed += loan.unpaid;
      lent++;
    } else {
      owe += loan.unpaid;
      borrowed++;
    }
  }
  return LoanSummary(
    owedToYou: owed,
    youOwe: owe,
    lentCount: lent,
    borrowedCount: borrowed,
    items: sorted,
  );
}

class CorrectionStats {
  const CorrectionStats({
    required this.count,
    required this.net,
    required this.absoluteTotal,
  });

  static const empty = CorrectionStats(count: 0, net: 0, absoluteTotal: 0);

  final int count;
  final double net;

  /// Total size of the adjustments regardless of direction.
  final double absoluteTotal;

  /// Several corrections in a month usually means entries were missed.
  bool get suggestsMissedEntries => count >= 3;
}

class IncomeSlice {
  const IncomeSlice({
    required this.label,
    required this.amount,
    required this.count,
  });

  final String label;
  final double amount;
  final int count;
}

class MerchantStat {
  const MerchantStat({
    required this.name,
    required this.count,
    required this.total,
  });

  final String name;
  final int count;
  final double total;
}

/// Insights for one period's transactions. [summary] should already be
/// filtered to the period.
class ExpenseInsights {
  const ExpenseInsights({
    this.savings = SavingsStats.empty,
    this.loans = LoanSummary.empty,
    this.corrections = CorrectionStats.empty,
    this.incomeMix = const [],
    this.merchants = const [],
    this.recurring = const [],
    this.projection,
    this.typicalMonth,
  });

  static const empty = ExpenseInsights();

  final SavingsStats savings;
  final LoanSummary loans;
  final CorrectionStats corrections;
  final List<IncomeSlice> incomeMix;
  final List<MerchantStat> merchants;
  final List<RecurringSeries> recurring;
  final MonthProjection? projection;
  final double? typicalMonth;
}

/// Titles that name an action rather than a place.
const _genericTitles = {
  '',
  'cash out',
  'cash in',
  'cashout',
  'withdrawn',
  'transaction',
  'initial record',
  'recharge',
};

ExpenseInsights computeExpenseInsights(
  ExpensesSummary summary, {
  DateTime? now,
  DateTime? periodStart,
}) {
  final today = now ?? DateTime.now();
  final txs = summary.transactions;

  var saved = 0.0;
  var withdrawn = 0.0;
  var deposits = 0;
  var correctionCount = 0;
  var correctionNet = 0.0;
  var correctionAbs = 0.0;
  final incomeBy = <String, double>{};
  final incomeCount = <String, int>{};
  final merchantTotal = <String, double>{};
  final merchantCount = <String, int>{};
  final merchantName = <String, String>{};
  var income = 0.0;

  for (final t in txs) {
    if (t.savedAmount > 0) {
      saved += t.savedAmount;
      deposits++;
    }
    withdrawn += t.withdrawnAmount;
    if (t.isBalanceCorrection) {
      correctionCount++;
      correctionNet += t.amount;
      correctionAbs += t.amount.abs();
    }
    if (t.isRealIncome) {
      income += t.amount.abs();
      final sub = t.subcategory?.trim();
      final label = sub == null || sub.isEmpty ? 'Other' : sub;
      incomeBy[label] = (incomeBy[label] ?? 0) + t.amount.abs();
      incomeCount[label] = (incomeCount[label] ?? 0) + 1;
    }
    if (t.isRealExpense) {
      final title = t.title?.trim() ?? '';
      final key = title.toLowerCase();
      if (!_genericTitles.contains(key)) {
        merchantTotal[key] = (merchantTotal[key] ?? 0) + t.amount.abs();
        merchantCount[key] = (merchantCount[key] ?? 0) + 1;
        merchantName.putIfAbsent(key, () => title);
      }
    }
  }

  final incomeMix = [
    for (final e in incomeBy.entries)
      IncomeSlice(
        label: e.key,
        amount: e.value,
        count: incomeCount[e.key] ?? 0,
      ),
  ]..sort((a, b) => b.amount.compareTo(a.amount));

  final merchants = [
    for (final e in merchantTotal.entries)
      if ((merchantCount[e.key] ?? 0) >= 2)
        MerchantStat(
          name: merchantName[e.key]!,
          count: merchantCount[e.key]!,
          total: e.value,
        ),
  ]..sort((a, b) => b.total.compareTo(a.total));

  final net = saved - withdrawn;
  return ExpenseInsights(
    savings: SavingsStats(
      saved: saved,
      withdrawn: withdrawn,
      deposits: deposits,
      rate: income > 0 ? net / income : null,
    ),
    loans: summarizeLoans(summary.loans),
    corrections: CorrectionStats(
      count: correctionCount,
      net: correctionNet,
      absoluteTotal: correctionAbs,
    ),
    incomeMix: incomeMix,
    merchants: merchants.take(8).toList(),
    recurring: summary.recurring,
    projection: periodStart == null
        ? null
        : projectMonth(
            spentSoFar: summary.totalRealExpenses,
            history: summary.history,
            periodStart: periodStart,
            now: today,
          ),
    typicalMonth: typicalMonthlySpend(summary.history, now: today),
  );
}
