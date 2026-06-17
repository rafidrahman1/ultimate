import 'package:intl/intl.dart';

import 'package:personal/core/period_range.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/period_comparison.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_anomaly_filter.dart';
import 'package:personal/features/progress_review/progress_review_evaluation.dart';
import 'package:personal/features/results/derived_metric_validation.dart';

const _calendarImpactWindowDays = 3;
const _timedAssociationWindowBefore = Duration(hours: 12);
const _timedAssociationWindowAfter = Duration(hours: 6);
const expenseContextMinIncomeShare = 0.03;
const expenseContextMinTotalBdt = 1000;

class ExpensePromptContext {
  const ExpensePromptContext({
    this.previousExpenses,
    this.sourceSummary,
    this.monthlyIncomeBdt,
    this.monthlyBudgetBdt,
    this.financialInstruction = '',
    this.period,
    this.calendarEvents = const [],
  });

  final ExpensesSummary? previousExpenses;
  /// Full CSV import used to derive the previous month when [previousExpenses] is null.
  final ExpensesSummary? sourceSummary;
  final String? monthlyIncomeBdt;
  final String? monthlyBudgetBdt;
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

  _writeIncome(buffer, baseline, currency);
  _writeBudgetStatus(
    buffer,
    monthlyIncome: baseline,
    monthlyBudget: monthlyBudget,
    totalSpent: summary.totalRealExpenses,
    currency: currency,
  );
  _writeBudgetAllocation(
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
  _writeMonthlySpend(
    buffer,
    totalSpend: summary.totalRealExpenses,
    savingsRemaining: summary.netSurplus,
    currency: currency,
  );
  _writeHighValuePurchases(buffer, report.anomalies, currency: currency);
  final concentration = buildExpenseConcentrationText(summary);
  if (concentration.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(concentration);
  }
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
    baseline: baseline,
    calendarEvents: context.calendarEvents,
  );

  return buffer.toString().trimRight();
}

/// Resolves previous-month spend from explicit context or [sourceSummary] CSV data.
ExpensesSummary? resolvePreviousExpenses(ExpensePromptContext context) {
  if (context.previousExpenses != null) return context.previousExpenses;
  final period = context.period;
  final source = context.sourceSummary;
  if (period == null || source == null) return null;
  return source.previousCalendarMonthSummary(period);
}

String previousMonthLabelForPeriod(AnalysisPeriod period) =>
    DateFormat('MMMM yyyy').format(
      previousCalendarMonthRange(period.dataMonthStart).start,
    );

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

double? resolveMonthlyBudgetBdt({
  String? monthlyBudgetBdt,
  String financialInstruction = '',
}) {
  final fromField = parseMonthlyIncomeBdt(monthlyBudgetBdt ?? '');
  if (fromField != null && fromField > 0) return fromField;
  return parseMonthlyBudgetBdt(financialInstruction);
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

void _writeBudgetAllocation(
  StringBuffer buffer, {
  required double monthlyIncome,
  required double? monthlyBudget,
  required double totalSpent,
  required String currency,
}) {
  buffer
    ..writeln()
    ..writeln('Budget Allocation:');

  if (monthlyBudget == null) {
    buffer.writeln('- Monthly budget: not configured');
  } else {
    buffer.writeln('- Monthly budget: ${formatExpenseMoney(monthlyBudget)}');
  }

  buffer.writeln(
    '- Total spent: ${formatExpenseMoney(totalSpent, alwaysTwoDecimals: true)} $currency',
  );

  if (monthlyBudget != null && monthlyBudget > 0) {
    final utilization = DerivedMetricValidation.sanitizePercent(
      totalSpent / monthlyBudget * 100,
    );
    if (utilization != null) {
      buffer.writeln('- Budget utilization %: ${formatExpensePercent(utilization)}');
    }

    final overrunPercent = DerivedMetricValidation.sanitizePercent(
      totalSpent > monthlyBudget
          ? (totalSpent - monthlyBudget) / monthlyBudget * 100
          : 0,
    );
    if (overrunPercent != null) {
      buffer.writeln('- Budget overrun %: ${formatExpensePercent(overrunPercent)}');
    }
  } else {
    buffer
      ..writeln('- Budget utilization %: n/a')
      ..writeln('- Budget overrun %: n/a');
  }

  if (monthlyIncome > 0) {
    final incomeUtilization = DerivedMetricValidation.sanitizePercent(
      totalSpent / monthlyIncome * 100,
    );
    if (incomeUtilization != null) {
      buffer.writeln(
        '- Income utilization %: ${formatExpensePercent(incomeUtilization)}',
      );
    }
  } else {
    buffer.writeln('- Income utilization %: n/a');
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
  List<ExpenseAnomaly> anomalies, {
  required String currency,
}) {
  final purchases = anomalies
      .where((anomaly) => !ExpensesSummary.isFuelExpense(anomaly.transaction))
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
      ..writeln(
        '- Amount: ${formatExpenseMoney(tx.amount.abs())} $currency',
      );
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
    final largest = purchases.reduce(
      (a, b) => a.amount.abs() >= b.amount.abs() ? a : b,
    );
    _writeEventAssociationLines(
      buffer,
      transaction: largest,
      calendarEvents: calendarEvents,
    );
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

bool qualifiesForExpenseContext({
  required ExpenseCategoryStat stat,
  required double incomeBaseline,
}) {
  if (stat.total >= expenseContextMinTotalBdt) return true;
  if (incomeBaseline > 0 &&
      stat.total / incomeBaseline >= expenseContextMinIncomeShare) {
    return true;
  }
  return false;
}

void _writeExpenseContextTags(
  StringBuffer buffer, {
  required ExpensesSummary summary,
  required double baseline,
  required List<MajorCalendarEvent> calendarEvents,
}) {
  final targets = summary.expensesByCategory
      .where((stat) => qualifiesForExpenseContext(
            stat: stat,
            incomeBaseline: baseline,
          ))
      .map((stat) => stat.category)
      .toList();
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
    buffer.writeln('$category:');
    _writeEventAssociationLines(
      buffer,
      transaction: largest,
      calendarEvents: calendarEvents,
    );
  }
}

void _writeEventAssociationLines(
  StringBuffer buffer, {
  required CashewTransaction transaction,
  required List<MajorCalendarEvent> calendarEvents,
}) {
  final association = findExpenseEventAssociation(
    transaction: transaction,
    calendarEvents: calendarEvents,
  );
  if (association.hasAssociation) {
    buffer
      ..writeln(
        '- Potential event association: ${association.eventName}',
      )
      ..writeln('- Timing: ${association.timingDetail}');
  } else {
    buffer.writeln('- No nearby event association');
  }
}

class ExpenseEventAssociation {
  const ExpenseEventAssociation({
    this.eventName,
    this.timingDetail,
    this.distanceMinutes,
  });

  final String? eventName;
  final String? timingDetail;
  final int? distanceMinutes;

  bool get hasAssociation =>
      eventName != null && timingDetail != null && distanceMinutes != null;
}

ExpenseEventAssociation findExpenseEventAssociation({
  required CashewTransaction transaction,
  required List<MajorCalendarEvent> calendarEvents,
  int windowDays = _calendarImpactWindowDays,
}) {
  final purchaseAt = transaction.date.toLocal();
  ExpenseEventAssociation? nearest;
  int? nearestDistanceMinutes;

  for (final event in calendarEvents) {
    final candidate = event.allDay || event.isHoliday
        ? _associationForAllDayEvent(
            purchaseAt: purchaseAt,
            event: event,
            windowDays: windowDays,
          )
        : _associationForTimedEvent(
            purchaseAt: purchaseAt,
            event: event,
          );
    if (candidate == null) continue;

    final distance = candidate.distanceMinutes!;
    if (nearestDistanceMinutes == null || distance < nearestDistanceMinutes) {
      nearest = candidate;
      nearestDistanceMinutes = distance;
    }
  }

  return nearest ?? const ExpenseEventAssociation();
}

ExpenseEventAssociation? _associationForTimedEvent({
  required DateTime purchaseAt,
  required MajorCalendarEvent event,
}) {
  final eventStart = event.start.toLocal();
  final eventEnd = event.end.toLocal();
  if (!eventEnd.isAfter(eventStart)) return null;

  final distanceMinutes = _minutesFromEventWindow(
    purchaseAt,
    eventStart,
    eventEnd,
  );
  if (purchaseAt.isBefore(eventStart)) {
    final leadTime = eventStart.difference(purchaseAt);
    if (leadTime > _timedAssociationWindowBefore) return null;
    return ExpenseEventAssociation(
      eventName: event.title,
      timingDetail:
          '${_formatAssociationOffset(leadTime)} before event start '
          '(${_formatExpenseDateTime(eventStart)})',
      distanceMinutes: distanceMinutes,
    );
  }

  if (!purchaseAt.isAfter(eventEnd)) {
    return ExpenseEventAssociation(
      eventName: event.title,
      timingDetail:
          'during event (${_formatExpenseDateTime(eventStart)}–'
          '${_formatExpenseDateTime(eventEnd)})',
      distanceMinutes: distanceMinutes,
    );
  }

  final lagTime = purchaseAt.difference(eventEnd);
  if (lagTime > _timedAssociationWindowAfter) return null;
  return ExpenseEventAssociation(
    eventName: event.title,
    timingDetail:
        '${_formatAssociationOffset(lagTime)} after event end '
        '(${_formatExpenseDateTime(eventEnd)})',
    distanceMinutes: distanceMinutes,
  );
}

ExpenseEventAssociation? _associationForAllDayEvent({
  required DateTime purchaseAt,
  required MajorCalendarEvent event,
  required int windowDays,
}) {
  final purchaseDay = _dateOnly(purchaseAt);
  final eventStartDay = _dateOnly(event.start);
  final eventEndDay = _dateOnly(event.end);

  final int dayOffset;
  if (purchaseDay.isBefore(eventStartDay)) {
    dayOffset = -eventStartDay.difference(purchaseDay).inDays;
  } else if (purchaseDay.isAfter(eventEndDay)) {
    dayOffset = purchaseDay.difference(eventEndDay).inDays;
  } else {
    dayOffset = 0;
  }

  if (dayOffset.abs() > windowDays) return null;

  final timingDetail = switch (dayOffset) {
    < 0 => '${dayOffset.abs()} day${dayOffset.abs() == 1 ? '' : 's'} '
        'before event start',
    > 0 => '$dayOffset day${dayOffset == 1 ? '' : 's'} after event end',
    _ => 'during event dates',
  };

  return ExpenseEventAssociation(
    eventName: event.title,
    timingDetail: timingDetail,
    distanceMinutes: dayOffset.abs() * 24 * 60,
  );
}

int _minutesFromEventWindow(
  DateTime purchaseAt,
  DateTime eventStart,
  DateTime eventEnd,
) {
  if (!purchaseAt.isBefore(eventStart) && !purchaseAt.isAfter(eventEnd)) {
    return 0;
  }
  if (purchaseAt.isBefore(eventStart)) {
    return eventStart.difference(purchaseAt).inMinutes;
  }
  return purchaseAt.difference(eventEnd).inMinutes;
}

String _formatAssociationOffset(Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes < 60) return '${totalMinutes}m';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _formatExpenseDateTime(DateTime dateTime) =>
    DateFormat('d MMM HH:mm').format(dateTime.toLocal());

@Deprecated('Use findExpenseEventAssociation instead')
ExpenseContextClassification classifyExpenseContext({
  required CashewTransaction transaction,
  required List<MajorCalendarEvent> calendarEvents,
}) {
  final association = findExpenseEventAssociation(
    transaction: transaction,
    calendarEvents: calendarEvents,
  );
  if (association.hasAssociation) {
    return ExpenseContextClassification(
      eventLinked: true,
      eventName: association.eventName,
      classification: 'Potential event association',
    );
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

String buildExpenseConcentrationText(ExpensesSummary summary) {
  final categories = summary.expensesByCategory;
  if (categories.isEmpty) return '';

  final baseline = summary.totalIncome > 0
      ? summary.totalIncome
      : summary.totalRealExpenses;
  final top = categories.first;
  final top3Total =
      categories.take(3).fold<double>(0, (sum, category) => sum + category.total);

  final topShare =
      baseline > 0 ? DerivedMetricValidation.sanitizePercent(top.total / baseline * 100) : null;
  final top3Share = baseline > 0
      ? DerivedMetricValidation.sanitizePercent(top3Total / baseline * 100)
      : null;

  final realExpenses =
      summary.transactions.where((transaction) => transaction.isRealExpense).toList();
  CashewTransaction? largest;
  for (final transaction in realExpenses) {
    if (largest == null ||
        transaction.amount.abs() > largest.amount.abs()) {
      largest = transaction;
    }
  }

  final buffer = StringBuffer('Expense Concentration:');
  if (topShare != null) {
    buffer
      ..writeln()
      ..writeln('- Top category share: ${formatExpensePercent(topShare)}');
  }
  if (top3Share != null) {
    buffer.writeln('- Top 3 category share: ${formatExpensePercent(top3Share)}');
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

String _highValuePurchaseDescription(CashewTransaction transaction) {
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
