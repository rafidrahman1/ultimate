import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/expenses/cashew_csv_parser.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';

void main() {
  test('executive summary derives totals from the sample Cashew export', () {
    final content =
        File('test/features/expenses/sample_cashew.csv').readAsStringSync();

    final summary = ExpensesSummary(
      transactions: parseCashewCsv(content),
    );

    expect(summary.totalIncome, closeTo(35000, 0.01));
    expect(summary.totalRealExpenses, closeTo(200, 0.01));
    expect(summary.netSurplus, closeTo(34800, 0.01));
    expect(summary.burnRate, closeTo(200 / 35000, 0.0001));
  });

  test('expensesByCategory groups real spending only', () {
    final summary = ExpensesSummary(
      transactions: [
        CashewTransaction(
          account: 'Bank',
          amount: -100,
          currency: 'BDT',
          date: DateTime(2026, 5, 1),
          isIncome: false,
          category: 'Food',
        ),
        CashewTransaction(
          account: 'Bank',
          amount: -50,
          currency: 'BDT',
          date: DateTime(2026, 5, 2),
          isIncome: false,
          category: 'Food',
        ),
        CashewTransaction(
          account: 'Bank',
          amount: -200,
          currency: 'BDT',
          date: DateTime(2026, 5, 3),
          isIncome: false,
          category: 'Transport',
        ),
        CashewTransaction(
          account: 'Bank',
          amount: 35000,
          currency: 'BDT',
          date: DateTime(2026, 5, 4),
          isIncome: true,
          category: 'Cash In',
        ),
        CashewTransaction(
          account: 'Bank',
          amount: -10,
          currency: 'BDT',
          date: DateTime(2026, 5, 5),
          isIncome: false,
          category: 'Balance Correction',
        ),
      ],
    );

    final categories = summary.expensesByCategory;
    expect(categories, hasLength(2));
    expect(categories[0].category, 'Transport');
    expect(categories[0].total, 200);
    expect(categories[0].count, 1);
    expect(categories[1].category, 'Food');
    expect(categories[1].total, 150);
    expect(categories[1].count, 2);
  });

  test('toFinancialContextCategoriesBlock lists subcategories from import', () {
    final summary = ExpensesSummary(
      transactions: [
        CashewTransaction(
          account: 'Bank',
          amount: -200,
          currency: 'BDT',
          date: DateTime(2026, 5, 3),
          isIncome: false,
          category: 'Transport',
          subcategory: 'Fuel',
        ),
        CashewTransaction(
          account: 'Bank',
          amount: -100,
          currency: 'BDT',
          date: DateTime(2026, 5, 1),
          isIncome: false,
          category: 'Food',
          subcategory: 'Restaurant',
        ),
      ],
    );

    expect(
      summary.toFinancialContextCategoriesBlock(),
      '* Fuel\n* Restaurant',
    );
  });

  test('toAnalysisPromptText excludes income and balance corrections', () {
    final summary = ExpensesSummary(
      transactions: [
        CashewTransaction(
          account: 'Bank',
          amount: -100,
          currency: 'BDT',
          date: DateTime(2026, 5, 1),
          isIncome: false,
          category: 'Food',
          subcategory: 'Groceries',
          title: 'Weekly shop',
        ),
        CashewTransaction(
          account: 'Bank',
          amount: 35000,
          currency: 'BDT',
          date: DateTime(2026, 5, 4),
          isIncome: true,
          category: 'Cash In',
        ),
      ],
    );

    final text = summary.toAnalysisPromptText();
    expect(text, startsWith('Expense Summary'));
    expect(text, contains('- Monthly income: 35,000 BDT'));
    expect(text, contains('- Total spent: 100.00 BDT'));
    expect(text, contains('1. Groceries'));
    expect(text, contains('- Total: 100.00'));
    expect(text, isNot(contains('High-Value Purchases:')));
    expect(text, isNot(contains('Cash In')));
  });

  test('formatPurchasePromptLine omits repeated date for same-day purchases', () {
    final fuel = CashewTransaction(
      account: 'Bank',
      amount: -80,
      currency: 'BDT',
      date: DateTime(2026, 5, 2, 9),
      isIncome: false,
      category: 'Transport',
      subcategory: 'Fuel',
    );
    final snacks = CashewTransaction(
      account: 'Bank',
      amount: -20,
      currency: 'BDT',
      date: DateTime(2026, 5, 2, 18),
      isIncome: false,
      category: 'Food',
      subcategory: 'Groceries',
      title: 'Snacks',
    );

    expect(
      ExpensesSummary.formatPurchasePromptLine(
        fuel,
        currency: 'BDT',
        showDate: true,
      ),
      '  - 2026-05-02 · Fuel: 80.00 BDT',
    );
    expect(
      ExpensesSummary.formatPurchasePromptLine(
        snacks,
        currency: 'BDT',
        showDate: false,
      ),
      '  - Groceries · Snacks: 20.00 BDT',
    );
  });
}
