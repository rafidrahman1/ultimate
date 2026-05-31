import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/expenses/cashew_csv_parser.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';

void main() {
  test('executive summary matches Cashew May export', () {
    final paths = [
      r"c:\Users\DOC\CrossDevice\Rafid's S22\storage\Download\cashew-2026-05-22-16-29-44-322799.csv",
      'test/features/expenses/sample_cashew.csv',
    ];

    String? content;
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        content = file.readAsStringSync();
        break;
      }
    }
    expect(content, isNotNull);

    final summary = ExpensesSummary(
      transactions: parseCashewCsv(content!),
    );

    expect(summary.totalIncome, closeTo(35000, 0.01));
    expect(summary.totalRealExpenses, closeTo(28064.80, 0.01));
    expect(summary.netSurplus, closeTo(6935.20, 0.01));
    expect(summary.burnRate, closeTo(0.8019, 0.0001));
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
    expect(text, contains('Total real expenses: 100.00 BDT'));
    expect(text, contains('Expense anomalies: none detected'));
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
