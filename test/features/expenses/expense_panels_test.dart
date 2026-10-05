import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_insights.dart';
import 'package:personal/features/expenses/expense_panels.dart';

final _money = NumberFormat.currency(symbol: '৳', decimalDigits: 0);

MonthlyExpenseRow _row(int month, double spend) => MonthlyExpenseRow(
  month: DateTime(2026, month),
  spend: spend,
  income: 40000,
  saved: 0,
  withdrawn: 0,
  corrections: 0,
  correctionNet: 0,
);

final _loans = summarizeLoans([
  CashewLoan(
    direction: CashewTxType.borrowed,
    unpaid: 15000,
    date: DateTime(2026, 5, 10),
    currency: 'BDT',
    person: 'Emon',
    note: 'Loan from family',
  ),
  CashewLoan(
    direction: CashewTxType.borrowed,
    unpaid: 4000,
    date: DateTime(2026, 6, 9),
    currency: 'BDT',
    person: 'Khalid',
  ),
  CashewLoan(
    direction: CashewTxType.lent,
    unpaid: 7000,
    date: DateTime(2025, 5, 8),
    currency: 'BDT',
    person: 'Imran',
  ),
  for (var i = 0; i < 6; i++)
    CashewLoan(
      direction: CashewTxType.lent,
      unpaid: 500.0 + i,
      date: DateTime(2025, 1 + i, 3),
      currency: 'BDT',
    ),
]);

final _series = [
  RecurringSeries(
    label: 'Eid',
    cadence: 'monthly',
    cadenceDays: 30,
    typicalAmount: -1000,
    count: 3,
    first: DateTime(2026, 7, 15),
    last: DateTime(2026, 9, 15),
    total: -3000,
  ),
  RecurringSeries(
    label: 'Fancy',
    cadence: 'weekly',
    cadenceDays: 7,
    typicalAmount: -100,
    count: 26,
    first: DateTime(2025, 5, 1),
    last: DateTime(2025, 10, 30),
    total: -2600,
  ),
  RecurringSeries(
    label: 'Pizza Party',
    cadence: 'weekly',
    cadenceDays: 7,
    typicalAmount: -100,
    count: 25,
    first: DateTime(2025, 4, 28),
    last: DateTime(2025, 10, 13),
    total: -2500,
  ),
  RecurringSeries(
    label: 'Vespa',
    cadence: 'weekly',
    cadenceDays: 7,
    typicalAmount: -100,
    count: 4,
    first: DateTime(2025, 1, 16),
    last: DateTime(2025, 2, 6),
    total: -400,
  ),
];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(1080, 12000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 4000),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final scale in [1.0, 2.0]) {
    group('at ${scale}x text on a 360dp screen', () {
      testWidgets('month pace, trend and corrections lay out', (t) async {
        await _pump(
          t,
          Column(
            children: [
              MonthPacePanel(
                projection: const MonthProjection(
                  spentSoFar: 12500,
                  projected: 41200,
                  typicalMonth: 30485,
                  daysElapsed: 11,
                  daysInMonth: 31,
                ),
                money: _money,
              ),
              MonthlyTrendPanel(
                history: [for (var m = 1; m <= 9; m++) _row(m, 8000.0 * m)],
                typicalMonth: 30485,
                money: _money,
              ),
              CorrectionsHint(
                stats: const CorrectionStats(
                  count: 8,
                  net: -12,
                  absoluteTotal: 100520,
                ),
                money: _money,
              ),
            ],
          ),
          scale: scale,
        );
        expect(t.takeException(), isNull);
        expect(find.text('THIS MONTH'), findsOneWidget);
        expect(find.textContaining('Above a normal month'), findsOneWidget);
        expect(find.text('SPENDING BY MONTH'), findsOneWidget);
        expect(find.text('8 balance corrections'), findsOneWidget);
      });

      testWidgets('savings and debts lay out', (t) async {
        await _pump(
          t,
          Column(
            children: [
              SavingsPanel(
                savings: const SavingsStats(
                  saved: 44200,
                  withdrawn: 2000,
                  deposits: 3,
                  rate: 0.27,
                ),
                recurring: _series,
                money: _money,
                now: DateTime(2026, 9, 30),
              ),
              DebtsPanel(loans: _loans, money: _money),
              IncomeMixPanel(
                slices: const [
                  IncomeSlice(label: 'Salary', amount: 50000, count: 1),
                  IncomeSlice(label: 'Gifts', amount: 2000, count: 3),
                ],
                money: _money,
              ),
              RepeatPlacesPanel(
                merchants: const [
                  MerchantStat(name: 'Chicken Buzz', count: 16, total: 5200),
                ],
                money: _money,
              ),
            ],
          ),
          scale: scale,
        );
        expect(t.takeException(), isNull);
        expect(find.text('SAVINGS'), findsOneWidget);
        expect(find.text('DEBTS'), findsOneWidget);
        expect(find.text('Chicken Buzz'), findsOneWidget);
      });
    });
  }

  testWidgets('pace says below a normal month when under', (t) async {
    await _pump(
      t,
      MonthPacePanel(
        projection: const MonthProjection(
          spentSoFar: 1000,
          projected: 20000,
          typicalMonth: 30000,
          daysElapsed: 4,
          daysInMonth: 31,
        ),
        money: _money,
      ),
    );
    expect(find.textContaining('Below a normal month'), findsOneWidget);
  });

  testWidgets('debts lead with the largest and say who owes whom', (t) async {
    await _pump(t, DebtsPanel(loans: _loans, money: _money));
    expect(find.text('9 unsettled'), findsOneWidget);
    expect(find.text('Emon'), findsOneWidget);
    expect(find.text('You borrowed · 10 May 2026'), findsOneWidget);
    expect(find.text('You lent · 8 May 2025'), findsOneWidget);
    // The three smallest are summarised, not listed.
    expect(find.text('+3 smaller'), findsOneWidget);
    expect(
      find.text('৳19,000'),
      findsOneWidget,
      reason: 'you owe 15,000 + 4,000',
    );
  });

  testWidgets('savings shows running entries before ended ones', (t) async {
    await _pump(
      t,
      SavingsPanel(
        savings: SavingsStats.empty,
        recurring: _series,
        money: _money,
        now: DateTime(2026, 9, 30),
      ),
    );
    expect(
      find.text('Nothing moved into savings in this period.'),
      findsOneWidget,
    );
    expect(find.text('active'), findsOneWidget);
    expect(find.text('Eid'), findsOneWidget);
    expect(find.textContaining('last Oct 2025'), findsOneWidget);
    expect(find.text('+2 more'), findsOneWidget);
  });

  testWidgets('savings with no recurring entries has no recurring section', (
    t,
  ) async {
    await _pump(
      t,
      SavingsPanel(
        savings: const SavingsStats(saved: 5000, withdrawn: 0, deposits: 1),
        recurring: const [],
        money: _money,
      ),
    );
    expect(find.text('Recurring'), findsNothing);
    expect(find.text('put aside'), findsOneWidget);
  });
}
