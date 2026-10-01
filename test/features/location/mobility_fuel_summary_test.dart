import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/location/mobility_prompt_builder.dart';

CashewTransaction _fuel(double amount, String? note) => CashewTransaction(
  account: 'Cash',
  amount: -amount,
  currency: 'BDT',
  date: DateTime(2026, 9, 10),
  isIncome: false,
  category: 'Fuel',
  note: note,
);

void main() {
  test('sums litres from price-per-litre descriptions', () {
    final fuel = mobilityFuelSummaryFromExpenses(
      ExpensesSummary(
        transactions: [
          _fuel(500, '125/L'),
          _fuel(260, 'Octane 130 per litre'),
          _fuel(300, null),
        ],
      ),
    )!;

    expect(fuel.refuelCount, 3);
    expect(fuel.pricedRefuels, hasLength(2));
    expect(fuel.totalLitres, closeTo(6.0, 1e-9));
    expect(fuel.weightedRatePerLitre, closeTo(760 / 6, 1e-9));
  });

  test('returns null litres when no description has a rate', () {
    final fuel = mobilityFuelSummaryFromExpenses(
      ExpensesSummary(transactions: [_fuel(500, 'Filled up')]),
    )!;

    expect(fuel.totalLitres, isNull);
    expect(fuel.weightedRatePerLitre, isNull);
  });
}
