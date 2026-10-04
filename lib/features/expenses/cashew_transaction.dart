import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/core/period_range.dart';
import 'package:personal/features/expenses/expense_anomaly_filter.dart';
import 'package:personal/features/expenses/expense_insights.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';

/// Cashew's `type` column.
enum CashewTxType {
  normal,

  /// An instance of a recurring rule; the rule is in `extra`.
  repetitive,

  /// Money you lent out. The amount still owed is in `amount unpaid`.
  lent,

  /// Money you borrowed. The amount you still owe is in `amount unpaid`.
  borrowed,

  /// Scheduled, not yet happened.
  upcoming;

  static CashewTxType parse(String? raw) => switch (raw?.trim().toLowerCase()) {
    'repetitive' => repetitive,
    'lent' => lent,
    'borrowed' => borrowed,
    'upcoming' => upcoming,
    _ => normal,
  };
}

/// A person you lent to or borrowed from, with the amount still unsettled.
class CashewLoan {
  const CashewLoan({
    required this.direction,
    required this.unpaid,
    required this.date,
    required this.currency,
    this.person,
    this.note,
  });

  /// [CashewTxType.lent] (owed to you) or [CashewTxType.borrowed] (you owe).
  final CashewTxType direction;

  /// Always positive.
  final double unpaid;
  final DateTime date;
  final String currency;
  final String? person;
  final String? note;

  bool get owedToYou => direction == CashewTxType.lent;
}

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
    this.type = CashewTxType.normal,
    this.recurrence,
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
  final CashewTxType type;

  /// The recurring rule, e.g. `repeat every 1 week`.
  final String? recurrence;

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

  bool get isBalanceCorrection => _normalize(category) == 'balance correction';

  /// Salary and other money in, not account transfers or balance fixes.
  bool get isRealIncome =>
      isIncome &&
      amount > 0 &&
      !isBalanceCorrection &&
      _normalize(category) == 'cash in';

  /// Money set aside, not spent. Recorded as an outflow from a spending
  /// account in the `Savings` category.
  bool get isSavingsTransfer => _normalize(category) == 'savings';

  bool get _onSavingsAccount => _normalize(account).contains('saving');

  /// Amount put into savings by this entry, else 0. Savings are recorded
  /// from either side: an outflow from a spending account, or an inflow on
  /// the savings account itself.
  double get savedAmount =>
      isSavingsTransfer && (_onSavingsAccount ? amount > 0 : amount < 0)
      ? amount.abs()
      : 0;

  /// Amount taken back out of savings by this entry, else 0.
  double get withdrawnAmount =>
      isSavingsTransfer && (_onSavingsAccount ? amount < 0 : amount > 0)
      ? amount.abs()
      : 0;

  /// Lending, borrowing and loan repayments: money moving between you and
  /// other people, not consumption.
  bool get isLoanMovement =>
      _normalize(category) == 'loan' ||
      type == CashewTxType.lent ||
      type == CashewTxType.borrowed;

  /// Spending, not transfers between accounts, balance adjustments, savings
  /// or loans.
  bool get isRealExpense =>
      amount < 0 &&
      !isBalanceCorrection &&
      !isSavingsTransfer &&
      !isLoanMovement;

  static String _normalize(String? value) => value?.trim().toLowerCase() ?? '';
}

class ExpensesSummary {
  const ExpensesSummary({
    required this.transactions,
    this.fileName,
    this.anomalyFilter = const ExpenseAnomalyFilter(),
    this.loans = const [],
    this.history = const [],
    this.recurring = const [],
    this.isLegacyCache = false,
  });

  final List<CashewTransaction> transactions;
  final String? fileName;
  final ExpenseAnomalyFilter anomalyFilter;

  /// Unsettled lent/borrowed records. Not filtered by period: a debt is a
  /// balance, not a month's activity.
  final List<CashewLoan> loans;

  /// Month-by-month totals over the whole export. Set by [forAnalysisPeriod],
  /// which sees the full history.
  final List<MonthlyExpenseRow> history;

  /// Repeating entries found in the full export.
  final List<RecurringSeries> recurring;

  /// True for data restored from a cache written before loans and recurrence
  /// were read. It works, but a reload adds the new detail.
  final bool isLegacyCache;

  ExpensesSummary forAnalysisPeriod(AnalysisPeriod period) {
    final filtered = transactions
        .where(
          (t) =>
              isDateInRange(t.date, period.dataMonthStart, period.dataMonthEnd),
        )
        .toList();
    return ExpensesSummary(
      transactions: filtered,
      fileName: fileName,
      anomalyFilter: anomalyFilter,
      loans: loans,
      history: history.isNotEmpty ? history : buildMonthlyExpenseHistory(this),
      recurring: recurring.isNotEmpty
          ? recurring
          : detectRecurringSeries(transactions),
    );
  }

  /// Full previous calendar month from the same expense history.
  ExpensesSummary? previousCalendarMonthSummary(AnalysisPeriod period) {
    final range = previousCalendarMonthRange(period.dataMonthStart);
    final previous = forAnalysisPeriod(
      AnalysisPeriod(
        dataMonthStart: range.start,
        dataMonthEnd: range.end,
        checklistMonthStart: period.checklistMonthStart,
      ),
    );
    if (previous.transactions.isEmpty) return null;
    return previous;
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

  int get realExpenseCount => transactions.where((t) => t.isRealExpense).length;

  /// Real spending grouped by subcategory, highest total first.
  List<ExpenseCategoryStat> get expensesByCategory {
    final totals = <String, double>{};
    final counts = <String, int>{};

    for (final tx in transactions) {
      if (!tx.isRealExpense) continue;
      final label = subcategoryLabel(tx);
      totals[label] = (totals[label] ?? 0) + tx.amount.abs();
      counts[label] = (counts[label] ?? 0) + 1;
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

  /// Bullet list of expense subcategories for financial contextualization rules.
  String toFinancialContextCategoriesBlock() {
    final categories = expensesByCategory;
    if (categories.isEmpty) {
      return '* (no expense categories in import)';
    }
    return categories.map((stat) => '* ${stat.category}').join('\n');
  }

  /// Structured expense block for AI analysis prompts.
  String toAnalysisPromptText({
    ExpensePromptContext context = const ExpensePromptContext(),
  }) => buildExpensePromptText(
    this,
    anomalyFilter: anomalyFilter,
    context: context,
  );

  static String formatPurchasePromptLine(
    CashewTransaction transaction, {
    required String currency,
    required bool showDate,
  }) {
    final label = purchasePromptLabel(transaction);
    final amount = '${transaction.amount.abs().toStringAsFixed(2)} $currency';
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

  static bool isFuelExpense(CashewTransaction transaction) {
    final category = transaction.category?.trim().toLowerCase() ?? '';
    final subcategory = transaction.subcategory?.trim().toLowerCase() ?? '';
    return category == 'fuel' || subcategory == 'fuel';
  }

  /// Extracts fuel rate from description text (e.g. "140/L", "140 per litre").
  static double? fuelRatePerLitreFromDescription(
    CashewTransaction transaction,
  ) {
    final candidates = <String>[
      if (transaction.note != null) transaction.note!,
      if (transaction.title != null) transaction.title!,
    ];

    final regex = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:/|per\s*)(?:l|ltr|litre|litres|liter|liters)\b',
      caseSensitive: false,
    );
    for (final text in candidates) {
      final match = regex.firstMatch(text);
      if (match == null) continue;
      final raw = match.group(1);
      final rate = raw == null ? null : double.tryParse(raw);
      if (rate != null && rate > 0) return rate;
    }
    return null;
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
