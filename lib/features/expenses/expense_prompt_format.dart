part of 'expense_prompt_builder.dart';

List<CashewTransaction> _transactionsForCategory(
  ExpensesSummary summary,
  String category,
) {
  return summary.transactions
      .where(
        (tx) =>
            tx.isRealExpense &&
            ExpensesSummary.subcategoryLabel(tx) == category,
      )
      .toList();
}

String buildExpenseCategoryProfilesText(ExpensesSummary summary) {
  final categories = summary.expensesByCategory;
  if (categories.isEmpty) return '';

  final buffer = StringBuffer();
  for (final stat in categories) {
    _writeCategoryProfile(buffer, summary: summary, stat: stat);
    buffer.writeln();
  }
  return buffer.toString().trimRight();
}

String buildExpenseConcentrationText(ExpensesSummary summary) {
  final categories = summary.expensesByCategory;
  if (categories.isEmpty) return '';

  final totalSpent = summary.totalRealExpenses;
  final top = categories.first;
  final top3Total = categories
      .take(3)
      .fold<double>(0, (sum, category) => sum + category.total);

  final topShare = totalSpent > 0
      ? DerivedMetricValidation.sanitizePercent(top.total / totalSpent * 100)
      : null;
  final top3Share = totalSpent > 0
      ? DerivedMetricValidation.sanitizePercent(top3Total / totalSpent * 100)
      : null;

  final realExpenses = summary.transactions
      .where((transaction) => transaction.isRealExpense)
      .toList();
  CashewTransaction? largest;
  for (final transaction in realExpenses) {
    if (largest == null || transaction.amount.abs() > largest.amount.abs()) {
      largest = transaction;
    }
  }

  final buffer = StringBuffer('Expense Concentration:');
  if (topShare != null) {
    buffer
      ..writeln()
      ..writeln(
        '- Top category share (of spending): ${formatPercent1dp(topShare)}',
      );
  }
  if (top3Share != null) {
    buffer.writeln(
      '- Top 3 category share (of spending): ${formatPercent1dp(top3Share)}',
    );
  }
  if (largest != null) {
    buffer
      ..writeln(
        '- Largest purchase: ${formatExpenseMoney(largest.amount.abs())} ${summary.currency}',
      )
      ..writeln('- Category: ${ExpensesSummary.subcategoryLabel(largest)}');
  }
  return buffer.toString().trimRight();
}

String _highValuePurchaseDescription(CashewTransaction transaction) {
  final title = transaction.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  return ExpensesSummary.subcategoryLabel(transaction);
}

String _spendingShareSuffix(double amount, double totalSpent) {
  if (totalSpent <= 0) return '';
  final percent = amount / totalSpent * 100;
  return ' (${formatPercent1dp(percent)} of spending)';
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String formatExpenseDate(DateTime date) =>
    DateFormat('d MMM').format(date.toLocal());

String formatExpenseMoney(double amount, {bool alwaysTwoDecimals = false}) {
  final rounded = roundTo2dp(amount.abs());
  final negative = amount < 0;

  if (alwaysTwoDecimals) {
    return _formatGroupedAmount(rounded, decimals: 2, negative: negative);
  }

  if (rounded == rounded.roundToDouble()) {
    return _formatGroupedAmount(rounded, decimals: 0, negative: negative);
  }

  return _formatGroupedAmount(rounded, decimals: 2, negative: negative);
}

String _formatGroupedAmount(
  double amount, {
  required int decimals,
  required bool negative,
}) {
  final fixed = amount.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final groupedInt = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  if (decimals == 0 || parts.length == 1) {
    return negative ? '-$groupedInt' : groupedInt;
  }
  final formatted = '$groupedInt.${parts[1]}';
  return negative ? '-$formatted' : formatted;
}
