import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/expenses/cashew_transaction.dart';

void main() {
  CashewTransaction tx(
    double amount,
    String? category, {
    bool income = false,
  }) => CashewTransaction(
    account: 'Cash',
    amount: amount,
    currency: 'BDT',
    date: DateTime(2026, 9, 3),
    isIncome: income,
    category: category,
  );

  final summary = ExpensesSummary(
    transactions: [
      tx(-500, 'Food'),
      tx(-2000, 'Investment'),
      tx(-100, null),
      tx(40000, 'Cash In', income: true),
    ],
  );

  test('lists distinct expense categories', () {
    expect(summary.expenseCategoryNames, [
      'Food',
      'Investment',
      'Uncategorized',
    ]);
  });

  test('excluded categories drop out of expense totals only', () {
    final filtered = summary.withoutExpenseCategories({
      'Investment',
      'Uncategorized',
    });

    expect(filtered.totalRealExpenses, 500);
    expect(filtered.totalIncome, 40000);
    expect(filtered.expensesByCategory.map((s) => s.category), ['Food']);
  });

  test('empty exclusion set is a no-op', () {
    expect(summary.withoutExpenseCategories({}).totalRealExpenses, 2600);
  });
}
