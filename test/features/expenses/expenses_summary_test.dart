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
}
