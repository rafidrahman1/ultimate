import 'package:intl/intl.dart';

import 'package:personal/core/formatting.dart';
import 'package:personal/core/period_range.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/period_comparison.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/fuel_forecast.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_anomaly_filter.dart';
import 'package:personal/features/expenses/expense_money_flow_text.dart';
import 'package:personal/features/progress_review/progress_review_evaluation.dart';
import 'package:personal/features/results/derived_metric_validation.dart';
import 'package:personal/features/results/analytics_pipeline_validation.dart';

part 'expense_event_association.dart';
part 'expense_prompt_format.dart';

const _allDayNearbyWindowDays = 1;
const _postEventObservationWindow = Duration(days: 3);
const _timedDirectWindowBefore = Duration(minutes: 30);
const _timedDirectWindowAfter = Duration(minutes: 30);
const _timedNearbyWindowBefore = Duration(hours: 2);
const _timedNearbyWindowAfter = Duration(hours: 2);
const eventAssociationMinConfidence = 0.5;

class ExpensePromptContext {
  const ExpensePromptContext({
    this.previousExpenses,
    this.sourceSummary,
    this.monthlyIncomeBdt,
    this.monthlyBudgetBdt,
    this.financialInstruction = '',
    this.period,
    this.fuelForecast,
  });

  final ExpensesSummary? previousExpenses;

  /// Full expense history used to derive the previous month when [previousExpenses] is null.
  final ExpensesSummary? sourceSummary;
  final String? monthlyIncomeBdt;
  final String? monthlyBudgetBdt;
  final String financialInstruction;
  final AnalysisPeriod? period;

  /// Built from the whole export, not the period's transactions.
  final FuelForecast? fuelForecast;
}

String buildExpensePromptText(
  ExpensesSummary summary, {
  ExpenseAnomalyFilter anomalyFilter = const ExpenseAnomalyFilter(),
  ExpensePromptContext context = const ExpensePromptContext(),
}) {
  if (summary.transactions.isEmpty) return 'No expense data imported.';

  final realExpenses = summary.transactions
      .where((t) => t.isRealExpense)
      .toList();
  if (realExpenses.isEmpty) {
    return 'No real expense transactions in import.';
  }

  final baseline = _resolvedMonthlyIncome(summary, context.monthlyIncomeBdt);
  final currency = summary.currency;
  final categories = summary.expensesByCategory;
  final report = anomalyFilter.analyze(summary);
  final buffer = StringBuffer('Expense Summary');

  final previous = resolvePreviousExpenses(context);
  final previousMonthLabel = context.period == null
      ? null
      : DateFormat('MMMM yyyy').format(
          previousCalendarMonthRange(context.period!.dataMonthStart).start,
        );
  final trend = buildExpenseTrendText(
    current: summary,
    previous: previous,
    currency: currency,
    previousMonthLabel: previousMonthLabel,
  );
  if (trend != null) {
    buffer
      ..writeln()
      ..writeln()
      ..write(trend);
  }

  final monthlyBudget = resolveMonthlyBudgetBdt(
    monthlyBudgetBdt: context.monthlyBudgetBdt,
    financialInstruction: context.financialInstruction,
  );

  _writeFinancialSummary(
    buffer,
    monthlyIncome: baseline,
    monthlyBudget: monthlyBudget,
    totalSpent: summary.totalRealExpenses,
    currency: currency,
  );
  _writeSpendingPace(
    buffer,
    summary: summary,
    period: context.period,
    monthlyBudget: monthlyBudget,
    monthlyIncome: baseline,
  );
  _writeHighValuePurchases(buffer, report.anomalies, currency: currency);
  final concentration = buildExpenseConcentrationText(summary);
  if (concentration.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(concentration);
  }
  final anomalousCategories = <String>{
    for (final anomaly in report.anomalies)
      ExpensesSummary.subcategoryLabel(anomaly.transaction),
  };
  _writeCategoryRanking(
    buffer,
    summary: summary,
    categories: categories,
    totalSpent: summary.totalRealExpenses,
    anomalousCategories: anomalousCategories,
  );

  final moneyFlow = buildMoneyFlowText(
    summary,
    periodStart: context.period?.dataMonthStart,
    fuel: context.fuelForecast,
  );
  if (moneyFlow.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln()
      ..writeln(moneyFlow);
  }

  final output = buffer.toString().trimRight();
  final validationWarnings = AnalyticsPipelineValidation.validateExpenseMetrics(
    summary: summary,
    monthlyIncome: baseline,
    monthlyBudget: monthlyBudget,
  );
  AnalyticsPipelineValidation.logWarnings('expenses', validationWarnings);
  return output;
}

/// Resolves previous-month spend from explicit context or full [sourceSummary] history.
ExpensesSummary? resolvePreviousExpenses(ExpensePromptContext context) {
  if (context.previousExpenses != null) return context.previousExpenses;
  final period = context.period;
  final source = context.sourceSummary;
  if (period == null || source == null) return null;
  return source.previousCalendarMonthSummary(period);
}

String previousMonthLabelForPeriod(AnalysisPeriod period) => DateFormat(
  'MMMM yyyy',
).format(previousCalendarMonthRange(period.dataMonthStart).start);

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
  String? previousMonthLabel,
}) {
  final currentSpend = current.totalRealExpenses;
  final buffer = StringBuffer('Expenses Trend:')
    ..writeln()
    ..writeln(
      '- Current spend: ${formatExpenseMoney(currentSpend, alwaysTwoDecimals: true)} $currency',
    );

  final previousSpend = previous?.totalRealExpenses;
  if (previousSpend == null || previous!.transactions.isEmpty) {
    buffer.writeln('- Previous month spend: not available');
    return buffer.toString().trimRight();
  }

  final change = currentSpend - previousSpend;
  final percentChange = previousSpend > 0 ? change / previousSpend * 100 : null;
  final trend = trendForIncrease(absoluteChange: change, stableThreshold: 1);
  final previousLabel = previousMonthLabel == null || previousMonthLabel.isEmpty
      ? 'Previous month spend'
      : 'Previous month spend ($previousMonthLabel)';

  buffer
    ..writeln(
      '- $previousLabel: ${formatExpenseMoney(previousSpend, alwaysTwoDecimals: true)} $currency',
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
    RegExp(r'([\d,]+)\s*bdt\s*(?:monthly\s+)?budget', caseSensitive: false),
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

double? resolveMonthlyBudgetBdt({
  String? monthlyBudgetBdt,
  String financialInstruction = '',
}) {
  final fromField = parseMonthlyIncomeBdt(monthlyBudgetBdt ?? '');
  if (fromField != null && fromField > 0) return fromField;
  return parseMonthlyBudgetBdt(financialInstruction);
}

void _writeFinancialSummary(
  StringBuffer buffer, {
  required double monthlyIncome,
  required double? monthlyBudget,
  required double totalSpent,
  required String currency,
}) {
  buffer
    ..writeln()
    ..writeln('Financial Summary:');

  if (monthlyIncome > 0) {
    buffer.writeln(
      '- Monthly income: ${formatExpenseMoney(monthlyIncome)} $currency',
    );
  } else {
    buffer.writeln('- Monthly income: not available');
  }

  if (monthlyBudget == null) {
    buffer.writeln('- Monthly budget: not configured');
  } else {
    buffer.writeln('- Monthly budget: ${formatExpenseMoney(monthlyBudget)}');
  }

  buffer.writeln(
    '- Total spent: ${formatExpenseMoney(totalSpent, alwaysTwoDecimals: true)} '
    '$currency',
  );

  if (monthlyBudget != null && monthlyBudget > 0) {
    final consumed = DerivedMetricValidation.sanitizePercent(
      totalSpent / monthlyBudget * 100,
    );
    if (consumed != null) {
      buffer.writeln('- Budget consumed: ${formatPercent1dp(consumed)}');
    }

    final remainingBudget = monthlyBudget - totalSpent;
    if (remainingBudget < 0) {
      buffer.writeln(
        '- Budget overrun: '
        '${formatExpenseMoney(remainingBudget.abs(), alwaysTwoDecimals: true)}',
      );
      final overrunPercent = DerivedMetricValidation.sanitizePercent(
        (totalSpent - monthlyBudget) / monthlyBudget * 100,
      );
      if (overrunPercent != null) {
        buffer.writeln(
          '- Budget overrun %: ${formatPercent1dp(overrunPercent)}',
        );
      }
    } else {
      buffer.writeln(
        '- Remaining budget: '
        '${formatExpenseMoney(remainingBudget, alwaysTwoDecimals: true)}',
      );
    }
  }

  if (monthlyIncome > 0) {
    final incomeRemaining = monthlyIncome - totalSpent;
    buffer.writeln(
      '- Income remaining: '
      '${formatExpenseMoney(incomeRemaining, alwaysTwoDecimals: true)} $currency',
    );
    final incomeUtilization = DerivedMetricValidation.sanitizePercent(
      totalSpent / monthlyIncome * 100,
    );
    if (incomeUtilization != null) {
      buffer.writeln(
        '- Income utilization: ${formatPercent1dp(incomeUtilization)}',
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
    ..writeln('- Expected budget use: ${formatPercent1dp(expectedUse)}')
    ..writeln('- Actual: ${formatPercent1dp(actualUse)}')
    ..writeln('- Variance: ${formatSignedPercentChange(variance)}');
}

void _writeHighValuePurchases(
  StringBuffer buffer,
  List<ExpenseAnomaly> anomalies, {
  required String currency,
}) {
  final purchases =
      anomalies
          .where(
            (anomaly) => !ExpensesSummary.isFuelExpense(anomaly.transaction),
          )
          .toList()
        ..sort((a, b) => a.transaction.date.compareTo(b.transaction.date));

  if (purchases.isEmpty) return;

  buffer
    ..writeln()
    ..writeln('High-Value Purchases:');

  for (final anomaly in purchases) {
    final tx = anomaly.transaction;
    buffer
      ..writeln('- Date: ${formatExpenseDate(tx.date)}')
      ..writeln('- Category: ${ExpensesSummary.subcategoryLabel(tx)}')
      ..writeln('- Description: ${_highValuePurchaseDescription(tx)}')
      ..writeln('- Amount: ${formatExpenseMoney(tx.amount.abs())} $currency');
  }
}

void _writeCategoryRanking(
  StringBuffer buffer, {
  required ExpensesSummary summary,
  required List<ExpenseCategoryStat> categories,
  required double totalSpent,
  Set<String> anomalousCategories = const {},
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
      totalSpent: totalSpent,
      includeTiming:
          stat.count >= 5 || anomalousCategories.contains(stat.category),
    );
  }
}

void _writeCategoryProfile(
  StringBuffer buffer, {
  required ExpensesSummary summary,
  required ExpenseCategoryStat stat,
  int? rank,
  double totalSpent = 0,
  bool includeTiming = false,
}) {
  final prefix = rank == null ? '' : '$rank. ';
  final purchases = _transactionsForCategory(summary, stat.category)
    ..sort((a, b) => a.date.compareTo(b.date));

  buffer.writeln('$prefix${stat.category}');
  buffer.writeln(
    '- Total: ${formatExpenseMoney(stat.total, alwaysTwoDecimals: true)}'
    '${rank == null ? '' : _spendingShareSuffix(stat.total, totalSpent)}',
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
    if (includeTiming) {
      _writeExpenseTiming(buffer, purchases);
    }
  }
}

void _writeExpenseTiming(
  StringBuffer buffer,
  List<CashewTransaction> purchases,
) {
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
