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
  });

  final List<CashewTransaction> transactions;
  final String? fileName;

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

  String get currency {
    if (transactions.isEmpty) return '';
    return transactions.first.currency;
  }
}
