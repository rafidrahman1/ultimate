import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/expenses/cashew_csv_parser.dart';

void main() {
  test('parses Cashew CSV with quoted multiline notes', () {
    final csv = File('test/features/expenses/sample_cashew.csv').readAsStringSync();
    final transactions = parseCashewCsv(csv);

    expect(transactions, hasLength(2));

    expect(transactions[0].title, 'Coffee');
    expect(transactions[0].note, contains('NesCafe'));
    expect(transactions[0].amount, -200);
    expect(transactions[0].isIncome, isFalse);

    expect(transactions[1].isIncome, isTrue);
    expect(transactions[1].amount, 35000);
  });
}
