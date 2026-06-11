import 'package:intl/intl.dart';

import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_anomaly_filter.dart';

String buildExpensePromptText(
  ExpensesSummary summary, {
  ExpenseAnomalyFilter anomalyFilter = const ExpenseAnomalyFilter(),
}) {
  if (summary.transactions.isEmpty) return 'No expense data imported.';

  final realExpenses =
      summary.transactions.where((t) => t.isRealExpense).toList();
  if (realExpenses.isEmpty) {
    return 'No real expense transactions in import.';
  }

  final baseline = summary.totalIncome;
  final currency = summary.currency;
  final categories = summary.expensesByCategory;
  final report = anomalyFilter.analyze(summary);
  final buffer = StringBuffer('Expense Summary');

  _writeIncome(buffer, baseline, currency);
  _writeMonthlySpend(
    buffer,
    totalSpend: summary.totalRealExpenses,
    savingsRemaining: summary.netSurplus,
    currency: currency,
  );
  _writeTopCategories(buffer, categories, baseline);
  _writeHighValuePurchases(buffer, report.anomalies);
  _writeCategoryRanking(buffer, categories, baseline);

  return buffer.toString().trimRight();
}

void _writeIncome(StringBuffer buffer, double baseline, String currency) {
  buffer
    ..writeln()
    ..writeln()
    ..writeln('Income:');
  if (baseline > 0) {
    buffer.writeln(
      '- Monthly baseline: ${formatExpenseMoney(baseline)} $currency',
    );
  } else {
    buffer.writeln('- Monthly baseline: not available');
  }
}

void _writeMonthlySpend(
  StringBuffer buffer, {
  required double totalSpend,
  required double savingsRemaining,
  required String currency,
}) {
  buffer
    ..writeln()
    ..writeln('Monthly Spend:')
    ..writeln(
      '- Total: ${formatExpenseMoney(totalSpend, alwaysTwoDecimals: true)} '
      '$currency',
    )
    ..writeln(
      '- Savings Remaining: '
      '${formatExpenseMoney(savingsRemaining, alwaysTwoDecimals: true)} '
      '$currency',
    );
}

void _writeTopCategories(
  StringBuffer buffer,
  List<ExpenseCategoryStat> categories,
  double baseline,
) {
  if (categories.isEmpty) return;

  buffer
    ..writeln()
    ..writeln('Top Categories:');

  final top = categories.take(5).toList();
  for (var i = 0; i < top.length; i++) {
    _writeCategoryProfile(buffer, top[i], rank: i + 1, baseline: baseline);
    if (i < top.length - 1) buffer.writeln();
  }
}

void _writeHighValuePurchases(
  StringBuffer buffer,
  List<ExpenseAnomaly> anomalies,
) {
  final purchases = anomalies
      .where((anomaly) => !ExpensesSummary.isFuelExpense(anomaly.transaction))
      .toList()
    ..sort((a, b) => a.transaction.date.compareTo(b.transaction.date));

  if (purchases.isEmpty) return;

  buffer
    ..writeln()
    ..writeln('High-Value Purchases:');

  String? lastDateKey;
  for (final anomaly in purchases) {
    final tx = anomaly.transaction;
    final dateKey = _dateKey(tx.date);
    final showDate = dateKey != lastDateKey;
    lastDateKey = dateKey;

    final label = showDate
        ? ExpensesSummary.subcategoryLabel(tx)
        : _highValuePurchaseLabel(tx);
    final amount = formatExpenseMoney(tx.amount.abs());

    if (showDate) {
      buffer.writeln(
        '- ${formatExpenseDate(tx.date)}: $label $amount',
      );
    } else {
      buffer.writeln('- $label: $amount');
    }
  }
}

void _writeCategoryRanking(
  StringBuffer buffer,
  List<ExpenseCategoryStat> categories,
  double baseline,
) {
  if (categories.isEmpty) return;

  buffer
    ..writeln()
    ..writeln('Category Ranking:');

  for (var i = 0; i < categories.length; i++) {
    final stat = categories[i];
    _writeCategoryProfile(buffer, stat, rank: i + 1, baseline: baseline);
  }
}

void _writeCategoryProfile(
  StringBuffer buffer,
  ExpenseCategoryStat stat, {
  int? rank,
  double baseline = 0,
}) {
  final prefix = rank == null ? '' : '$rank. ';
  buffer.writeln('$prefix${stat.category}');
  buffer.writeln(
    '- Amount: ${formatExpenseMoney(stat.total, alwaysTwoDecimals: true)}'
    '${rank == null ? '' : _percentSuffix(stat.total, baseline)}',
  );
  buffer.writeln('- Purchases: ${stat.count}');
  buffer.writeln(
    '- Avg purchase: '
    '${formatExpenseMoney(stat.total / stat.count, alwaysTwoDecimals: true)}',
  );
}

String buildExpenseCategoryProfilesText(ExpensesSummary summary) {
  final categories = summary.expensesByCategory;
  if (categories.isEmpty) return '';

  final buffer = StringBuffer();
  for (final stat in categories) {
    _writeCategoryProfile(buffer, stat);
    buffer.writeln();
  }
  return buffer.toString().trimRight();
}

String _highValuePurchaseLabel(CashewTransaction transaction) {
  final title = transaction.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  return ExpensesSummary.subcategoryLabel(transaction);
}

String _percentSuffix(double amount, double baseline) {
  if (baseline <= 0) return '';
  final percent = amount / baseline * 100;
  return ' (${formatExpensePercent(percent)})';
}

String _dateKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month}-${local.day}';
}

String formatExpenseDate(DateTime date) =>
    DateFormat('d MMM').format(date.toLocal());

String formatExpensePercent(double percent) {
  final rounded = (percent * 10).roundToDouble() / 10;
  return '${rounded.toStringAsFixed(1)}%';
}

String formatExpenseMoney(
  double amount, {
  bool alwaysTwoDecimals = false,
}) {
  final rounded = (amount.abs() * 100).roundToDouble() / 100;
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
