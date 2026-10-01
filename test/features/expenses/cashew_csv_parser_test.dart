import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/expenses/cashew_csv_parser.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';

void main() {
  const csv =
      'account,amount,currency,title,note,date,income,'
      'category name,subcategory name\r\n'
      'Cash,-500,BDT,Octane,125/L,2026-09-03 10:15:00.000,false,Fuel,\r\n'
      'Bank,40000,BDT,Salary,,2026-09-01 09:00:00.000,true,Cash In,\r\n'
      ',,,,,,,,\r\n'
      'Cash,abc,BDT,Broken,,2026-09-04,false,Food,\r\n';

  test('parses rows, skips blank and malformed ones', () {
    final transactions = parseCashewCsv(csv);

    expect(transactions, hasLength(2));
    final fuel = transactions.first;
    expect(fuel.amount, -500);
    expect(fuel.category, 'Fuel');
    expect(fuel.subcategory, isNull);
    expect(fuel.date, DateTime(2026, 9, 3, 10, 15));
    expect(transactions[1].isIncome, isTrue);
  });

  test('summary separates real expenses and income', () {
    final summary = ExpensesSummary(transactions: parseCashewCsv(csv));

    expect(summary.totalRealExpenses, 500);
    expect(summary.totalIncome, 40000);
    expect(summary.burnRate, closeTo(0.0125, 1e-9));
    expect(ExpensesSummary.isFuelExpense(summary.transactions.first), isTrue);
    expect(
      ExpensesSummary.fuelRatePerLitreFromDescription(
        summary.transactions.first,
      ),
      125,
    );
  });

  test('detects tab-separated exports', () {
    final tsv = csv.replaceAll(',', '\t');
    expect(parseCashewCsv(tsv), hasLength(2));
  });

  test('balance corrections are not real expenses', () {
    final summary = ExpensesSummary(
      transactions: [
        CashewTransaction(
          account: 'Cash',
          amount: -1000,
          currency: 'BDT',
          date: DateTime(2026, 9, 2),
          isIncome: false,
          category: 'Balance Correction',
        ),
      ],
    );
    expect(summary.totalRealExpenses, 0);
  });
}
