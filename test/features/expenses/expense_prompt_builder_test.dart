import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_anomaly_filter.dart';

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
    expect(text, contains('Income:'));
    expect(text, contains('- Monthly baseline: 35,000 BDT'));
    expect(text, contains('Budget Allocation:'));
    expect(text, contains('- Budget utilization %:'));
    expect(text, contains('- Income utilization %:'));
    expect(text, contains('Monthly Spend:'));
    expect(text, contains('- Total:'));
    expect(text, contains('- Savings Remaining:'));
    expect(text, isNot(contains('Top Categories:')));
    expect(text, contains('1. Gifts'));
    expect(text, contains('- Total: 25,925.75 (74.1%)'));
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

    expect(text, contains('Expense Context:'));
    expect(text, contains('Gifts:'));
    expect(text, isNot(contains('Snacks:')));
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

    expect(text, contains('Monthly Spend:'));
    expect(text, contains('- Total: 180.00 BDT'));
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

    expect(text, contains('- Monthly baseline: not available'));
    expect(text, contains('1. Food'));
    expect(text, contains('- Total: 100.00'));
    expect(text, isNot(contains('(%)')));
  });
}
