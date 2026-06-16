import 'package:intl/intl.dart';

import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/period_comparison.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_anomaly_filter.dart';
import 'package:personal/features/progress_review/progress_review_evaluation.dart';

const _calendarImpactWindowDays = 3;

class ExpensePromptContext {
  const ExpensePromptContext({
    this.previousExpenses,
    this.monthlyIncomeBdt,
    this.financialInstruction = '',
    this.period,
    this.calendarEvents = const [],
  });

  final ExpensesSummary? previousExpenses;
  final String? monthlyIncomeBdt;
  final String financialInstruction;
  final AnalysisPeriod? period;
  final List<MajorCalendarEvent> calendarEvents;
}

String buildExpensePromptText(
  ExpensesSummary summary, {
  ExpenseAnomalyFilter anomalyFilter = const ExpenseAnomalyFilter(),
  ExpensePromptContext context = const ExpensePromptContext(),
}) {
  if (summary.transactions.isEmpty) return 'No expense data imported.';

  final realExpenses =
      summary.transactions.where((t) => t.isRealExpense).toList();
  if (realExpenses.isEmpty) {
    return 'No real expense transactions in import.';
  }

  final baseline = _resolvedMonthlyIncome(summary, context.monthlyIncomeBdt);
  final currency = summary.currency;
  final categories = summary.expensesByCategory;
  final report = anomalyFilter.analyze(summary);
  final buffer = StringBuffer('Expense Summary');

  final trend = buildExpenseTrendText(
    current: summary,
    previous: context.previousExpenses,
    currency: currency,
  );
  if (trend != null) {
    buffer
      ..writeln()
      ..writeln()
      ..write(trend);
  }

  _writeIncome(buffer, baseline, currency);
  _writeBudgetStatus(
    buffer,
    monthlyIncome: baseline,
    monthlyBudget: parseMonthlyBudgetBdt(context.financialInstruction),
    totalSpent: summary.totalRealExpenses,
    currency: currency,
  );
  _writeSpendingPace(
    buffer,
    summary: summary,
    period: context.period,
    monthlyBudget: parseMonthlyBudgetBdt(context.financialInstruction),
    monthlyIncome: baseline,
  );
  _writeMonthlySpend(
    buffer,
    totalSpend: summary.totalRealExpenses,
    savingsRemaining: summary.netSurplus,
    currency: currency,
  );
  _writeHighValuePurchases(buffer, report.anomalies);
  _writeCategoryRanking(
    buffer,
    summary: summary,
    categories: categories,
    baseline: baseline,
    calendarEvents: context.calendarEvents,
  );
  _writeExpenseContextTags(
    buffer,
    summary: summary,
    anomalies: report.anomalies,
    calendarEvents: context.calendarEvents,
  );

  return buffer.toString().trimRight();
}

double _resolvedMonthlyIncome(
  ExpensesSummary summary,
  String? monthlyIncomeBdt,
) {
  if (summary.totalIncome > 0) return summary.totalIncome;
  return parseMonthlyIncomeBdt(monthlyIncomeBdt ?? '') ?? 0;
}

String? buildExpenseTrendText({
  required ExpensesSummary current,
  ExpensesSummary? previous,
  required String currency,
}) {
  final currentSpend = current.totalRealExpenses;
  final buffer = StringBuffer('Expenses Trend:')
    ..writeln()
    ..writeln(
      '- Current spend: ${formatExpenseMoney(currentSpend, alwaysTwoDecimals: true)} $currency',
    );

  final previousSpend = previous?.totalRealExpenses;
  if (previousSpend == null || previous!.transactions.isEmpty) {
    buffer.writeln('- Previous spend: not available');
    return buffer.toString().trimRight();
  }

  final change = currentSpend - previousSpend;
  final percentChange = previousSpend > 0 ? change / previousSpend * 100 : null;
  final trend = trendForIncrease(absoluteChange: change, stableThreshold: 1);

  buffer
    ..writeln(
      '- Previous spend: ${formatExpenseMoney(previousSpend, alwaysTwoDecimals: true)} $currency',
    )
    ..writeln(
      '- Change: ${formatSignedMoneyChange(change, alwaysTwoDecimals: true)} $currency',
    );
  if (percentChange != null) {
    buffer.writeln('- Change %: ${formatSignedPercentChange(percentChange)}');
  }
  buffer.writeln('- Trend: ${formatTrendLabel(trend)}');

  return buffer.toString().trimRight();
}

double? parseMonthlyBudgetBdt(String financialInstruction) {
  final text = financialInstruction.trim();
  if (text.isEmpty) return null;

  final patterns = [
    RegExp(
      r'(?:monthly\s+)?budget[:\s]+(?:bdt\s*)?([\d,]+)',
      caseSensitive: false,
    ),
    RegExp(
      r'([\d,]+)\s*bdt\s*(?:monthly\s+)?budget',
      caseSensitive: false,
    ),
    RegExp(
      r'spend(?:ing)?\s*(?:cap|limit|max)[:\s]+(?:bdt\s*)?([\d,]+)',
      caseSensitive: false,
    ),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
      if (value != null && value > 0) return value;
    }
  }

  return null;
}

void _writeBudgetStatus(
  StringBuffer buffer, {
  required double monthlyIncome,
  required double? monthlyBudget,
  required double totalSpent,
  required String currency,
}) {
  buffer
    ..writeln()
    ..writeln('Budget Status:');

  if (monthlyIncome > 0) {
    buffer.writeln('- Monthly income: ${formatExpenseMoney(monthlyIncome)}');
  } else {
    buffer.writeln('- Monthly income: not available');
  }

  if (monthlyBudget == null) {
    buffer.writeln('- Monthly budget: not configured');
    return;
  }

  final consumed = monthlyBudget > 0 ? totalSpent / monthlyBudget * 100 : null;
  final remainingBudget = monthlyBudget - totalSpent;
  final incomeRemaining = monthlyIncome > 0 ? monthlyIncome - totalSpent : null;

  buffer
    ..writeln('- Monthly budget: ${formatExpenseMoney(monthlyBudget)}')
    ..writeln(
      '- Total spent: ${formatExpenseMoney(totalSpent, alwaysTwoDecimals: true)} $currency',
    );
  if (consumed != null) {
    buffer.writeln(
      '- Budget consumed: ${formatExpensePercent(consumed)}',
    );
  }
  if (remainingBudget < 0) {
    buffer.writeln(
      '- Budget overrun: ${formatExpenseMoney(remainingBudget.abs(), alwaysTwoDecimals: true)}',
    );
  } else {
    buffer.writeln(
      '- Remaining budget: ${formatExpenseMoney(remainingBudget, alwaysTwoDecimals: true)}',
    );
  }
  if (incomeRemaining != null) {
    final incomeRemainingPercent =
        monthlyIncome > 0 ? incomeRemaining / monthlyIncome * 100 : null;
    buffer.writeln(
      '- Income remaining: ${formatExpenseMoney(incomeRemaining, alwaysTwoDecimals: true)}',
    );
    if (incomeRemainingPercent != null) {
      buffer.writeln(
        '- Remaining income %: ${formatExpensePercent(incomeRemainingPercent)}',
      );
    }
  }
}

void _writeSpendingPace(
  StringBuffer buffer, {
  required ExpensesSummary summary,
  required AnalysisPeriod? period,
  required double? monthlyBudget,
  required double monthlyIncome,
}) {
  if (period == null) return;

  final dayOfMonth = period.dataMonthEnd.day;
  final daysInMonth = DateTime(
    period.dataMonthStart.year,
    period.dataMonthStart.month + 1,
    0,
  ).day;
  final budgetBase = monthlyBudget ?? monthlyIncome;
  if (budgetBase <= 0) return;

  final expectedUse = dayOfMonth / daysInMonth * 100;
  final actualUse = summary.totalRealExpenses / budgetBase * 100;
  final variance = actualUse - expectedUse;

  buffer
    ..writeln()
    ..writeln('Spending Pace:')
    ..writeln('- Day of month: $dayOfMonth')
    ..writeln('- Expected budget use: ${formatExpensePercent(expectedUse)}')
    ..writeln('- Actual: ${formatExpensePercent(actualUse)}')
    ..writeln('- Variance: ${formatSignedPercentChange(variance)}');
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
  StringBuffer buffer, {
  required ExpensesSummary summary,
  required List<ExpenseCategoryStat> categories,
  required double baseline,
  required List<MajorCalendarEvent> calendarEvents,
}) {
  if (categories.isEmpty) return;

  buffer
    ..writeln()
    ..writeln('Category Ranking:');

  for (var i = 0; i < categories.length; i++) {
    final stat = categories[i];
    _writeCategoryProfile(
      buffer,
      summary: summary,
      stat: stat,
      rank: i + 1,
      baseline: baseline,
      calendarEvents: calendarEvents,
    );
  }
}

void _writeCategoryProfile(
  StringBuffer buffer, {
  required ExpensesSummary summary,
  required ExpenseCategoryStat stat,
  int? rank,
  double baseline = 0,
  List<MajorCalendarEvent> calendarEvents = const [],
}) {
  final prefix = rank == null ? '' : '$rank. ';
  final purchases = _transactionsForCategory(summary, stat.category)
    ..sort((a, b) => a.date.compareTo(b.date));

  buffer.writeln('$prefix${stat.category}');
  buffer.writeln(
    '- Total: ${formatExpenseMoney(stat.total, alwaysTwoDecimals: true)}'
    '${rank == null ? '' : _percentSuffix(stat.total, baseline)}',
  );
  buffer.writeln('- Purchases: ${stat.count}');
  buffer.writeln(
    '- Avg purchase: '
    '${formatExpenseMoney(stat.total / stat.count, alwaysTwoDecimals: true)}',
  );

  if (purchases.isNotEmpty) {
    buffer.writeln('Purchases:');
    for (final tx in purchases) {
      buffer.writeln(
        '- ${formatExpenseDate(tx.date)}: '
        '${formatExpenseMoney(tx.amount.abs())}',
      );
    }
    _writeExpenseTiming(buffer, purchases);
  }
}

void _writeExpenseTiming(StringBuffer buffer, List<CashewTransaction> purchases) {
  if (purchases.isEmpty) return;

  final dates = purchases.map((tx) => _dateOnly(tx.date)).toList()..sort();
  final first = dates.first;
  final last = dates.last;
  final spanDays = last.difference(first).inDays;

  var largestGap = 0;
  for (var i = 1; i < dates.length; i++) {
    final gap = dates[i].difference(dates[i - 1]).inDays;
    if (gap > largestGap) largestGap = gap;
  }

  buffer
    ..writeln('Expense Timing:')
    ..writeln('- First purchase: ${formatExpenseDate(first)}')
    ..writeln('- Last purchase: ${formatExpenseDate(last)}')
    ..writeln('- Span: $spanDays days')
    ..writeln('- Largest gap: $largestGap days');
}

void _writeExpenseContextTags(
  StringBuffer buffer, {
  required ExpensesSummary summary,
  required List<ExpenseAnomaly> anomalies,
  required List<MajorCalendarEvent> calendarEvents,
}) {
  final categories = summary.expensesByCategory.take(5).map((s) => s.category);
  final anomalyCategories = anomalies
      .map((a) => ExpensesSummary.subcategoryLabel(a.transaction))
      .toSet();
  final targets = <String>{...categories, ...anomalyCategories};
  if (targets.isEmpty) return;

  buffer
    ..writeln()
    ..writeln('Expense Context:');
  for (final category in targets) {
    final purchases = _transactionsForCategory(summary, category);
    if (purchases.isEmpty) continue;
    final largest = purchases.reduce(
      (a, b) => a.amount.abs() >= b.amount.abs() ? a : b,
    );
    final context = classifyExpenseContext(
      transaction: largest,
      calendarEvents: calendarEvents,
    );
    buffer
      ..writeln('$category:')
      ..writeln('- Event-linked: ${context.eventLinked ? 'Yes' : 'No'}');
    if (context.eventName != null) {
      buffer.writeln('- Event: ${context.eventName}');
    }
    buffer.writeln('- Classification: ${context.classification}');
  }
}

class ExpenseContextClassification {
  const ExpenseContextClassification({
    required this.eventLinked,
    required this.classification,
    this.eventName,
  });

  final bool eventLinked;
  final String classification;
  final String? eventName;
}

ExpenseContextClassification classifyExpenseContext({
  required CashewTransaction transaction,
  required List<MajorCalendarEvent> calendarEvents,
}) {
  final purchaseDay = _dateOnly(transaction.date);
  for (final event in calendarEvents) {
    final eventStart = _dateOnly(event.start);
    final eventEnd = _dateOnly(event.end);
    final windowStart = eventStart.subtract(
      const Duration(days: _calendarImpactWindowDays),
    );
    final windowEnd = eventEnd.add(
      const Duration(days: _calendarImpactWindowDays),
    );
    if (!purchaseDay.isBefore(windowStart) && !purchaseDay.isAfter(windowEnd)) {
      return ExpenseContextClassification(
        eventLinked: true,
        eventName: event.impactLabel,
        classification: 'Event-linked',
      );
    }
  }

  final category = ExpensesSummary.subcategoryLabel(transaction).toLowerCase();
  if (_essentialCategories.contains(category)) {
    return const ExpenseContextClassification(
      eventLinked: false,
      classification: 'Essential',
    );
  }

  return const ExpenseContextClassification(
    eventLinked: false,
    classification: 'Unknown',
  );
}

const _essentialCategories = {
  'fuel',
  'groceries',
  'rent',
  'utilities',
  'medicine',
  'health',
  'transport',
};

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

String buildExpenseCategoryProfilesText(
  ExpensesSummary summary, {
  List<MajorCalendarEvent> calendarEvents = const [],
}) {
  final categories = summary.expensesByCategory;
  if (categories.isEmpty) return '';

  final buffer = StringBuffer();
  for (final stat in categories) {
    _writeCategoryProfile(
      buffer,
      summary: summary,
      stat: stat,
      calendarEvents: calendarEvents,
    );
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

DateTime _dateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

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
