import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/expenses/analysis/expense_insights.dart';

MonthlyExpenseRow month(int m, List<double> daily) => MonthlyExpenseRow(
  month: DateTime(2026, m),
  spend: daily.fold(0, (a, b) => a + b),
  income: 0,
  saved: 0,
  withdrawn: 0,
  corrections: 0,
  correctionNet: 0,
  dailySpend: daily,
);

// 30 days, half the month's spending (500 of 1000) lands by day 10.
List<double> shape() => [
  for (var d = 1; d <= 30; d++) d == 5 ? 500 : (d == 20 ? 500 : 0),
];

void main() {
  test('projects from how much earlier months had spent by this day', () {
    final history = [month(7, shape()), month(8, shape()), month(9, shape())];
    final p = projectMonth(
      spentSoFar: 600,
      history: history,
      periodStart: DateTime(2026, 11),
      now: DateTime(2026, 11, 10),
    )!;
    // Past months were 50% through by day 10, so 600 spent means 1200.
    expect(p.projected, closeTo(1200, 0.01));
    expect(p.comparedMonths, 3);
    expect(p.typicalSpentByNow, 500);
  });

  test('falls back to a normal daily rate without daily data', () {
    final flat = [
      for (var m = 7; m <= 9; m++)
        MonthlyExpenseRow(
          month: DateTime(2026, m),
          spend: 900,
          income: 0,
          saved: 0,
          withdrawn: 0,
          corrections: 0,
          correctionNet: 0,
        ),
    ];
    final p = projectMonth(
      spentSoFar: 300,
      history: flat,
      periodStart: DateTime(2026, 11),
      now: DateTime(2026, 11, 10),
    )!;
    expect(p.comparedMonths, 0);
    expect(p.projected, closeTo(300 + 900 / 30 * 20, 0.01));
  });
}
