import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_anomaly_filter.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';

CashewTransaction _expense({
  required double amount,
  required DateTime date,
  String? category,
  String? subcategory,
  String? title,
}) {
  return CashewTransaction(
    account: 'Bank',
    amount: -amount,
    currency: 'BDT',
    date: date,
    isIncome: false,
    category: category,
    subcategory: subcategory,
    title: title,
  );
}

CashewTransaction _income(double amount, DateTime date) {
  return CashewTransaction(
    account: 'Bank',
    amount: amount,
    currency: 'BDT',
    date: date,
    isIncome: true,
    category: 'Cash In',
  );
}

ExpensesSummary _summary(List<CashewTransaction> transactions) {
  return ExpensesSummary(transactions: transactions);
}

void main() {
  test('formats structured expense summary for analysis prompt', () {
    final text = _summary([
      _income(35000, DateTime(2026, 5, 1)),
      _expense(
        amount: 10515.75,
        date: DateTime(2026, 5, 8),
        category: 'Gifts',
        subcategory: 'Gifts',
      ),
      _expense(
        amount: 6000,
        date: DateTime(2026, 5, 18),
        category: 'Shopping',
        subcategory: 'Electronics',
        title: 'Leobog hi75',
      ),
      _expense(
        amount: 2126.85,
        date: DateTime(2026, 5, 4),
        category: 'Food',
        subcategory: 'Snacks',
      ),
      _expense(
        amount: 2000,
        date: DateTime(2026, 5, 6),
        category: 'Transport',
        subcategory: 'Fuel',
      ),
      _expense(
        amount: 1490,
        date: DateTime(2026, 5, 10),
        category: 'Finance',
        subcategory: 'Cashout',
      ),
      _expense(
        amount: 5190,
        date: DateTime(2026, 5, 8, 9),
        category: 'Gifts',
        subcategory: 'Gifts',
        title: 'Gift Purchase',
      ),
      _expense(
        amount: 6800,
        date: DateTime(2026, 5, 8, 12),
        category: 'Gifts',
        subcategory: 'Gifts',
        title: 'Gift Purchase',
      ),
      _expense(
        amount: 3420,
        date: DateTime(2026, 5, 8, 18),
        category: 'Gifts',
        subcategory: 'Gifts',
        title: 'Gift Purchase',
      ),
      for (var i = 0; i < 8; i++)
        _expense(
          amount: 250,
          date: DateTime(2026, 5, 20 + i),
          subcategory: 'Snacks',
        ),
    ]).toAnalysisPromptText();

    expect(text, startsWith('Expense Summary'));
    expect(text, contains('Financial Summary:'));
    expect(text, contains('- Monthly income: 35,000 BDT'));
    expect(text, contains('- Income utilization:'));
    expect(text, contains('- Total spent:'));
    expect(text, contains('- Income remaining:'));
    expect(text, isNot(contains('Budget Allocation:')));
    expect(text, isNot(contains('Budget Status:')));
    expect(text, isNot(contains('Monthly Spend:')));
    expect(text, isNot(contains('Income:')));
    expect(text, isNot(contains('Top Categories:')));
    expect(text, contains('1. Gifts'));
    expect(text, contains('- Total: 25,925.75 (65.6% of spending)'));
    expect(text, contains('2. Electronics'));
    expect(text, contains('- Avg purchase:'));
    expect(text, contains('High-Value Purchases:'));
    expect(text, contains('- Date: 8 May'));
    expect(text, contains('- Category: Gifts'));
    expect(text, contains('- Description: Gift Purchase'));
    expect(text, contains('- Amount: 6,800'));
    expect(text, contains('- Date: 18 May'));
    expect(text, contains('- Category: Electronics'));
    expect(text, contains('- Description: Leobog hi75'));
    expect(text, contains('Expense Concentration:'));
    expect(text, contains('Category Ranking:'));
    expect(text, isNot(contains('Cash In')));
    expect(text, isNot(contains('Fuel expenses:')));
  });

  test('expense context only includes categories above thresholds', () {
    final text = _summary([
      _income(35000, DateTime(2026, 5, 1)),
      _expense(
        amount: 10515.75,
        date: DateTime(2026, 5, 8),
        category: 'Gifts',
        subcategory: 'Gifts',
      ),
      for (var i = 0; i < 8; i++)
        _expense(
          amount: 100,
          date: DateTime(2026, 5, 20 + i),
          subcategory: 'Snacks',
        ),
    ]).toAnalysisPromptText();

    expect(text, contains('Category Ranking:'));
    expect(text, contains('1. Gifts'));
    expect(text, isNot(contains('Expense Context:')));
  });

  test('category ranking omits event links covered by calendar prompt', () {
    final text = _summary([
      _income(35000, DateTime(2026, 6, 1)),
      _expense(
        amount: 1175,
        date: DateTime(2026, 6, 14, 16, 45),
        category: 'Food',
        subcategory: 'Restaurant',
        title: 'Alfresco',
      ),
    ]).toAnalysisPromptText(
      context: ExpensePromptContext(
        calendarEvents: [
          MajorCalendarEvent(
            title: 'Wife outing',
            start: DateTime(2026, 6, 14, 18),
            end: DateTime(2026, 6, 14, 21),
            isHoliday: false,
          ),
        ],
      ),
    );

    expect(text, contains('1. Restaurant'));
    expect(text, isNot(contains('Event-linked purchase')));
    expect(text, isNot(contains('Nearby event')));
    expect(text, isNot(contains('No event association')));
    expect(text, isNot(contains('Expense Context:')));
  });

  test('does not link purchase far outside narrow timed event window', () {
    final text = _summary([
      _income(35000, DateTime(2026, 6, 1)),
      _expense(
        amount: 1175,
        date: DateTime(2026, 6, 14, 13, 20),
        category: 'Food',
        subcategory: 'Restaurant',
        title: 'Alfresco',
      ),
    ]).toAnalysisPromptText(
      context: ExpensePromptContext(
        calendarEvents: [
          MajorCalendarEvent(
            title: 'Wife outing',
            start: DateTime(2026, 6, 14, 18),
            end: DateTime(2026, 6, 14, 21),
            isHoliday: false,
          ),
        ],
      ),
    );

    expect(text, contains('1. Restaurant'));
    expect(text, isNot(contains('Event-linked purchase')));
    expect(text, isNot(contains('Nearby event')));
    expect(text, isNot(contains('No event association')));
  });

  test('does not link purchase far from timed event', () {
    final association = findExpenseEventAssociation(
      transaction: _expense(
        amount: 300,
        date: DateTime(2026, 6, 15, 18, 27),
        subcategory: 'Snacks',
      ),
      calendarEvents: [
        MajorCalendarEvent(
          title: 'Rick and Morty',
          start: DateTime(2026, 6, 15, 20),
          end: DateTime(2026, 6, 15, 22),
          isHoliday: false,
        ),
      ],
    );

    expect(association.hasAssociation, isTrue);
    expect(association.timingDetail, contains('1h 33m before event start'));
  });

  test('omits high-value section when spending is uniform', () {
    final text = _summary([
      _expense(
        amount: 100,
        date: DateTime(2026, 5, 1),
        category: 'Food',
        subcategory: 'Food',
      ),
      _expense(
        amount: 80,
        date: DateTime(2026, 5, 2),
        category: 'Transport',
        subcategory: 'Transport',
      ),
    ]).toAnalysisPromptText();

    expect(text, contains('Financial Summary:'));
    expect(text, contains('- Total spent: 180.00 BDT'));
    expect(text, isNot(contains('High-Value Purchases:')));
    expect(text, contains('Category Ranking:'));
    expect(text, contains('1. Food'));
    expect(text, contains('2. Transport'));
  });

  test('reports unavailable income baseline without salary inflow', () {
    final text = _summary([
      _expense(
        amount: 100,
        date: DateTime(2026, 5, 1),
        category: 'Food',
        subcategory: 'Food',
      ),
    ]).toAnalysisPromptText();

    expect(text, contains('- Monthly income: not available'));
    expect(text, contains('1. Food'));
    expect(text, contains('- Total: 100.00'));
    expect(text, isNot(contains('(%)')));
  });

  test('derives previous month spend from full CSV import', () {
    final period = AnalysisPeriod.forDataMonth(DateTime(2026, 6, 1));
    final full = ExpensesSummary(
      transactions: [
        _expense(
          amount: 500,
          date: DateTime(2026, 5, 10),
          subcategory: 'Snacks',
        ),
        _expense(
          amount: 1175,
          date: DateTime(2026, 6, 14, 13, 20),
          category: 'Food',
          subcategory: 'Restaurant',
          title: 'Alfresco',
        ),
      ],
    );
    final current = full.forAnalysisPeriod(period);

    final text = current.toAnalysisPromptText(
      context: ExpensePromptContext(
        period: period,
        sourceSummary: full,
        monthlyIncomeBdt: '35000',
      ),
    );

    expect(text, contains('Expenses Trend:'));
    expect(text, contains('- Previous month spend (May 2026): 500.00 BDT'));
    expect(text, contains('- Current spend: 1,175.00 BDT'));
    expect(text, contains('- Change: +675.00 BDT'));
  });

  test('uses full previous calendar month not month-to-date slice', () {
    final period = AnalysisPeriod(
      dataMonthStart: DateTime(2026, 6, 1),
      dataMonthEnd: DateTime(2026, 6, 17, 23, 59, 59, 999, 999),
      checklistMonthStart: DateTime(2026, 7, 1),
    );
    final full = ExpensesSummary(
      transactions: [
        _expense(
          amount: 21953.97,
          date: DateTime(2026, 5, 10),
          subcategory: 'Snacks',
        ),
        _expense(
          amount: 8332.58,
          date: DateTime(2026, 5, 25),
          subcategory: 'Restaurant',
        ),
        _expense(
          amount: 500,
          date: DateTime(2026, 6, 10),
          subcategory: 'Fuel',
        ),
      ],
    );
    final current = full.forAnalysisPeriod(period);

    final text = current.toAnalysisPromptText(
      context: ExpensePromptContext(
        period: period,
        sourceSummary: full,
      ),
    );

    expect(text, contains('- Previous month spend (May 2026): 30,286.55 BDT'));
    expect(text, isNot(contains('21,953.97')));
  });

  test('uses dedicated monthly budget field for utilization metrics', () {
    final text = _summary([
      _expense(
        amount: 25000,
        date: DateTime(2026, 5, 1),
        category: 'Food',
        subcategory: 'Food',
      ),
    ]).toAnalysisPromptText(
      context: const ExpensePromptContext(
        monthlyIncomeBdt: '80000',
        monthlyBudgetBdt: '50000',
      ),
    );

    expect(text, contains('- Monthly budget: 50,000'));
    expect(text, contains('- Budget consumed: 50.0%'));
    expect(text, contains('- Budget consumed: 50.0%'));
  });

  test('falls back to financial rules when monthly budget field is empty', () {
    final text = _summary([
      _expense(
        amount: 20000,
        date: DateTime(2026, 5, 1),
        category: 'Food',
        subcategory: 'Food',
      ),
    ]).toAnalysisPromptText(
      context: const ExpensePromptContext(
        monthlyIncomeBdt: '80000',
        financialInstruction: 'Keep monthly budget: 40,000 BDT',
      ),
    );

    expect(text, contains('- Monthly budget: 40,000'));
    expect(text, contains('- Budget consumed: 50.0%'));
  });
}
