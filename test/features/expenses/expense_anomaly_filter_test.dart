import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_anomaly_filter.dart';

ExpensesSummary _summary(List<CashewTransaction> transactions) {
  return ExpensesSummary(transactions: transactions);
}

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

void main() {
  const filter = ExpenseAnomalyFilter();

  test('flags large purchases and statistical outliers', () {
    final expenses = <CashewTransaction>[
      for (var i = 0; i < 8; i++)
        _expense(
          amount: 250,
          date: DateTime(2026, 5, i + 1),
          subcategory: 'Snacks',
        ),
      _expense(
        amount: 6000,
        date: DateTime(2026, 5, 18),
        subcategory: 'Electronics',
        title: 'Leobog hi75',
      ),
      _expense(
        amount: 1170,
        date: DateTime(2026, 5, 9),
        subcategory: 'Restaurant',
        title: 'Durbin Bangla',
      ),
    ];

    final report = filter.analyze(_summary(expenses));

    expect(report.anomalies.length, greaterThanOrEqualTo(2));
    expect(
      report.anomalies.any((a) => a.transaction.title == 'Leobog hi75'),
      isTrue,
    );
    expect(
      report.anomalies.any((a) => a.transaction.title == 'Durbin Bangla'),
      isTrue,
    );
    expect(
      report.anomalies.every((a) => a.transaction.amount.abs() >= 250),
      isTrue,
    );
  });

  test('does not flag routine small purchases', () {
    final report = filter.analyze(
      _summary([
        _expense(amount: 100, date: DateTime(2026, 5, 1), subcategory: 'Food'),
        _expense(amount: 80, date: DateTime(2026, 5, 2), subcategory: 'Fuel'),
        _expense(amount: 50, date: DateTime(2026, 5, 3), subcategory: 'Fuel'),
      ]),
    );

    expect(report.anomalies, isEmpty);
  });

  test('toPromptText includes total and only anomaly lines', () {
    final text = _summary([
      _expense(amount: 200, date: DateTime(2026, 5, 1), subcategory: 'Tea'),
      _expense(
        amount: 6800,
        date: DateTime(2026, 5, 8),
        subcategory: 'Gifts',
        title: 'Mama panjabi 2x',
      ),
    ]).toAnalysisPromptText();

    expect(text, contains('Total real expenses: 7000.00 BDT'));
    expect(text, contains('Mama panjabi 2x'));
    expect(text, isNot(contains('Tea: 200.00')));
    expect(text, isNot(contains('Expenses by subcategory')));
  });

  test('toPromptText reports none when spending is uniform', () {
    final text = _summary([
      _expense(amount: 100, date: DateTime(2026, 5, 1), subcategory: 'Food'),
      _expense(amount: 80, date: DateTime(2026, 5, 2), subcategory: 'Transport'),
    ]).toAnalysisPromptText();

    expect(text, contains('Expense anomalies: none detected'));
    expect(text, contains('Total real expenses: 180.00 BDT'));
  });

  test('toPromptText always includes fuel expenses with dates', () {
    final text = _summary([
      _expense(amount: 100, date: DateTime(2026, 5, 1), subcategory: 'Food'),
      _expense(amount: 80, date: DateTime(2026, 5, 2), subcategory: 'Fuel'),
      _expense(amount: 50, date: DateTime(2026, 5, 2, 18), subcategory: 'Fuel'),
      _expense(amount: 60, date: DateTime(2026, 5, 3), subcategory: 'Fuel'),
    ]).toAnalysisPromptText();

    expect(text, contains('Fuel expenses:'));
    expect(text, contains('2026-05-02 · Fuel: 80.00 BDT'));
    expect(text, contains('2026-05-02 · Fuel: 50.00 BDT'));
    expect(text, contains('2026-05-03 · Fuel: 60.00 BDT'));
    expect(text, isNot(contains('Food: 100.00')));
  });
}
