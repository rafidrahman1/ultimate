import '../../core/analysis_period.dart';
import '../../core/period_range.dart';
import 'expense_anomaly_filter.dart';

class CashewTransaction {
  const CashewTransaction({
    required this.account,
    required this.amount,
    required this.currency,
    required this.date,
    required this.isIncome,
    this.title,
    this.note,
    this.category,
    this.subcategory,
  });

  final String account;
  final double amount;
  final String currency;
  final DateTime date;
  final bool isIncome;
  final String? title;
  final String? note;
  final String? category;
  final String? subcategory;

  String get displayTitle {
    final parts = [
      if (title != null && title!.isNotEmpty) title,
      if (subcategory != null && subcategory!.isNotEmpty) subcategory,
      if (category != null && category!.isNotEmpty) category,
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
    return account;
  }

  double get signedAmount => isIncome ? amount.abs() : -amount.abs();

  bool get isBalanceCorrection =>
      _normalize(category) == 'balance correction';

  /// Salary and other money in, not account transfers or balance fixes.
  bool get isRealIncome =>
      isIncome &&
      amount > 0 &&
      !isBalanceCorrection &&
      _normalize(category) == 'cash in';

  /// Spending, not transfers between accounts or balance adjustments.
  bool get isRealExpense => amount < 0 && !isBalanceCorrection;

  static String _normalize(String? value) =>
      value?.trim().toLowerCase() ?? '';
}

class ExpensesSummary {
  const ExpensesSummary({
    required this.transactions,
    this.fileName,
    this.anomalyFilter = const ExpenseAnomalyFilter(),
  });

  final List<CashewTransaction> transactions;
  final String? fileName;
  final ExpenseAnomalyFilter anomalyFilter;

  ExpensesSummary forAnalysisPeriod(AnalysisPeriod period) {
    final filtered = transactions
        .where(
          (t) => isDateInRange(
            t.date,
            period.dataMonthStart,
            period.dataMonthEnd,
          ),
        )
        .toList();
    return ExpensesSummary(
      transactions: filtered,
      fileName: fileName,
      anomalyFilter: anomalyFilter,
    );
  }

  DateTime? get periodStart => minDateTime(transactions.map((t) => t.date));

  DateTime? get periodEnd => maxDateTime(transactions.map((t) => t.date));

  String? get periodRangeLabel {
    final start = periodStart;
    final end = periodEnd;
    if (start == null || end == null) return null;
    return formatPeriodRange(start, end);
  }

  List<CashewTransaction> get sortedByDate {
    final copy = List<CashewTransaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    return copy;
  }

  /// Negative outflows excluding balance corrections and internal transfers.
  double get totalRealExpenses => transactions
      .where((t) => t.isRealExpense)
      .fold(0.0, (sum, t) => sum + t.amount.abs());

  /// Salary and similar inflows (e.g. Cash In), not balance corrections.
  double get totalIncome => transactions
      .where((t) => t.isRealIncome)
      .fold(0.0, (sum, t) => sum + t.amount.abs());

  double get netSurplus => totalIncome - totalRealExpenses;

  double? get burnRate =>
      totalIncome > 0 ? totalRealExpenses / totalIncome : null;

  int get realExpenseCount =>
      transactions.where((t) => t.isRealExpense).length;

  /// Real spending grouped by category, highest total first.
  List<ExpenseCategoryStat> get expensesByCategory {
    final totals = <String, double>{};
    final counts = <String, int>{};

    for (final tx in transactions) {
      if (!tx.isRealExpense) continue;
      final category = _categoryLabel(tx.category);
      totals[category] = (totals[category] ?? 0) + tx.amount.abs();
      counts[category] = (counts[category] ?? 0) + 1;
    }

    return totals.entries
        .map(
          (entry) => ExpenseCategoryStat(
            category: entry.key,
            total: entry.value,
            count: counts[entry.key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  String get currency {
    if (transactions.isEmpty) return '';
    return transactions.first.currency;
  }

  /// Notable purchases only, plus period total, for AI analysis prompts.
  String toAnalysisPromptText() {
    if (transactions.isEmpty) return 'No expense data imported.';

    final realExpenses =
        transactions.where((t) => t.isRealExpense).toList();
    if (realExpenses.isEmpty) {
      return 'No real expense transactions in import.';
    }

    final report = anomalyFilter.analyze(this);
    final fuelExpenses = realExpenses.where(isFuelExpense).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return report.toPromptText(
      currency: currency,
      totalRealExpenses: totalRealExpenses,
      transactionCount: realExpenseCount,
      fuelExpenses: fuelExpenses,
    );
  }

  static String formatPurchasePromptLine(
    CashewTransaction transaction, {
    required String currency,
    required bool showDate,
  }) {
    final label = purchasePromptLabel(transaction);
    final amount =
        '${transaction.amount.abs().toStringAsFixed(2)} $currency';
    if (!showDate) return '  - $label: $amount';
    final date = transaction.date.toLocal().toIso8601String().split('T').first;
    return '  - $date · $label: $amount';
  }

  static String purchasePromptLabel(CashewTransaction transaction) {
    final subcategory = subcategoryLabel(transaction);
    final title = transaction.title?.trim();
    if (title != null && title.isNotEmpty) {
      return '$subcategory · $title';
    }
    return subcategory;
  }

  static String subcategoryLabel(CashewTransaction transaction) {
    final sub = transaction.subcategory?.trim();
    if (sub != null && sub.isNotEmpty) return sub;
    final category = transaction.category?.trim();
    if (category != null && category.isNotEmpty) return category;
    return 'Uncategorized';
  }

  static int _localDateKey(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day).millisecondsSinceEpoch;
  }

  static String _categoryLabel(String? category) {
    final trimmed = category?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'Uncategorized';
    return trimmed;
  }

  static bool isFuelExpense(CashewTransaction transaction) {
    final category = transaction.category?.trim().toLowerCase() ?? '';
    final subcategory = transaction.subcategory?.trim().toLowerCase() ?? '';
    return category == 'fuel' || subcategory == 'fuel';
  }
}

class ExpenseCategoryStat {
  const ExpenseCategoryStat({
    required this.category,
    required this.total,
    required this.count,
  });

  final String category;
  final double total;
  final int count;
}
