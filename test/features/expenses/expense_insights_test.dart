import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/expenses/cashew_csv_parser.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_insights.dart';
import 'package:personal/features/expenses/expense_money_flow_text.dart';

/// Mirrors a real Cashew export: loan rows have an empty `amount` and the
/// money in `amount unpaid`; recurring rules sit in `extra`.
const _header =
    'account,amount,amount unpaid,currency,title,note,date,income,type,'
    'category name,subcategory name,color,icon,emoji,budget,objective,extra,'
    'transaction id,last modified';

String _row({
  String account = 'Bank',
  String amount = '',
  String unpaid = '',
  String title = '',
  String note = '',
  required String date,
  bool income = false,
  String type = 'default',
  required String category,
  String sub = '',
  String emoji = '',
  String extra = '',
}) =>
    '$account,$amount,$unpaid,BDT,$title,$note,$date.000,$income,$type,'
    '$category,$sub,0XFF000000,icon,$emoji,,,$extra,id-$date-$title,$date.000';

final _csv = [
  _header,
  // Spending
  _row(
    amount: '-500',
    title: 'Swapno',
    date: '2026-09-02 12:00:00',
    category: 'Personal Essentials',
  ),
  _row(
    amount: '-700',
    title: 'Swapno',
    date: '2026-09-09 12:00:00',
    category: 'Personal Essentials',
  ),
  _row(
    amount: '-300',
    title: 'Bfc',
    date: '2026-09-05 20:00:00',
    category: 'Food',
    sub: 'Snacks',
  ),
  _row(
    amount: '-585',
    title: 'Cash out',
    date: '2026-09-06 13:00:00',
    category: 'Cashout',
  ),
  // Income
  _row(
    amount: '50000',
    title: 'Salary',
    date: '2026-09-01 09:00:00',
    income: true,
    category: 'Cash In',
    sub: 'Salary',
  ),
  _row(
    amount: '2000',
    title: 'Gift',
    date: '2026-09-12 09:00:00',
    income: true,
    category: 'Cash In',
    sub: 'Gifts',
  ),
  // Savings: from Bank (outflow) and on the Savings account (inflow)
  _row(
    amount: '-10000',
    title: 'Fancy',
    date: '2026-09-03 10:00:00',
    category: 'Savings',
  ),
  _row(
    account: 'Savings',
    amount: '5000',
    date: '2026-09-04 10:00:00',
    income: true,
    category: 'Savings',
  ),
  _row(
    account: 'Savings',
    amount: '-2000',
    date: '2026-09-20 10:00:00',
    category: 'Savings',
  ),
  // A loan repayment: not spending
  _row(
    account: 'Savings',
    amount: '-77216.95',
    date: '2026-09-21 10:00:00',
    category: 'Loan',
  ),
  // Balance corrections
  _row(
    amount: '-120',
    date: '2026-09-07 10:00:00',
    category: 'Balance Correction',
  ),
  _row(
    amount: '120',
    date: '2026-09-08 10:00:00',
    income: true,
    category: 'Balance Correction',
  ),
  _row(
    amount: '-60',
    date: '2026-09-09 10:00:00',
    category: 'Balance Correction',
  ),
  // Loan records: empty amount
  _row(
    unpaid: '-500',
    title: 'Siam Bhai',
    note: 'Gave 500',
    date: '2026-08-04 10:00:00',
    type: 'lent',
    category: 'Loan',
  ),
  _row(
    unpaid: '15000',
    title: 'Emon',
    date: '2026-05-10 10:00:00',
    type: 'borrowed',
    category: 'Loan',
  ),
  _row(
    unpaid: '1000',
    title: 'Saba',
    date: '2026-06-08 10:00:00',
    type: 'borrowed',
    category: 'Loan',
  ),
  // Recurring weekly savings, amounts vary
  _row(
    amount: '-100',
    title: 'Pizza Party',
    date: '2025-05-05 10:00:00',
    type: 'repetitive',
    category: 'Savings',
    extra: 'repeat every 1 week',
  ),
  _row(
    amount: '-100',
    title: 'Pizza Party',
    date: '2025-05-12 10:00:00',
    type: 'repetitive',
    category: 'Savings',
    extra: 'repeat every 1 week',
  ),
  _row(
    amount: '-150',
    title: 'Pizza Party',
    date: '2025-05-19 10:00:00',
    type: 'repetitive',
    category: 'Savings',
    extra: 'repeat every 1 week',
  ),
  _row(
    amount: '-1000',
    title: 'Eid',
    date: '2026-09-15 10:00:00',
    type: 'repetitive',
    category: 'Savings',
    extra: 'repeat every 1 month',
  ),
  _row(
    amount: '-1000',
    title: 'Eid',
    date: '2026-08-15 10:00:00',
    type: 'repetitive',
    category: 'Savings',
    extra: 'repeat every 1 month',
  ),
  // Emoji column
  _row(
    amount: '-50',
    date: '2026-09-10 10:00:00',
    category: 'Deed',
    emoji: '🎗',
  ),
].join('\n');

void main() {
  final export = parseCashewExport(_csv);

  group('parser', () {
    test('keeps lent and borrowed records that have no amount', () {
      expect(export.loans, hasLength(3));
      final siam = export.loans.firstWhere((l) => l.person == 'Siam Bhai');
      expect(siam.owedToYou, isTrue);
      expect(siam.unpaid, 500, reason: 'always positive');
      expect(export.loans.where((l) => !l.owedToYou), hasLength(2));
    });

    test('loan rows are not transactions', () {
      expect(export.transactions.any((t) => t.title == 'Siam Bhai'), isFalse);
    });

    test('reads type and the recurring rule', () {
      final eid = export.transactions.firstWhere((t) => t.title == 'Eid');
      expect(eid.type, CashewTxType.repetitive);
      expect(eid.recurrence, 'repeat every 1 month');
      final plain = export.transactions.firstWhere((t) => t.title == 'Swapno');
      expect(plain.type, CashewTxType.normal);
      expect(plain.recurrence, isNull);
    });

    test('survives an emoji column', () {
      expect(export.transactions.any((t) => t.category == 'Deed'), isTrue);
    });

    test('still works when the new columns are absent', () {
      final old = parseCashewExport(
        'account,amount,currency,title,note,date,income,category name,subcategory name\n'
        'Cash,-500,BDT,Octane,,2026-09-03 10:15:00.000,false,Fuel,\n',
      );
      expect(old.transactions, hasLength(1));
      expect(old.loans, isEmpty);
      expect(old.transactions.single.type, CashewTxType.normal);
    });
  });

  group('classification', () {
    final byTitle = {for (final t in export.transactions) t.title ?? '': t};

    test('savings and loan repayments are not spending', () {
      expect(byTitle['Fancy']!.isRealExpense, isFalse);
      final loan = export.transactions.firstWhere((t) => t.category == 'Loan');
      expect(loan.isRealExpense, isFalse);
      expect(loan.isLoanMovement, isTrue);
    });

    test('ordinary purchases and cash-outs still are', () {
      expect(byTitle['Swapno']!.isRealExpense, isTrue);
      expect(byTitle['Cash out']!.isRealExpense, isTrue);
    });

    test('savings are read from either side', () {
      final fromBank = byTitle['Fancy']!;
      expect(fromBank.savedAmount, 10000);
      expect(fromBank.withdrawnAmount, 0);

      final deposit = export.transactions.firstWhere(
        (t) => t.account == 'Savings' && t.amount == 5000,
      );
      expect(deposit.savedAmount, 5000);

      final withdrawal = export.transactions.firstWhere(
        (t) => t.account == 'Savings' && t.amount == -2000,
      );
      expect(withdrawal.withdrawnAmount, 2000);
      expect(withdrawal.savedAmount, 0);
    });

    test('real spend excludes everything that is not consumption', () {
      final summary = ExpensesSummary(transactions: export.transactions);
      final sep = summary.transactions.where(
        (t) => t.date.month == 9 && t.date.year == 2026,
      );
      final spend = sep
          .where((t) => t.isRealExpense)
          .fold<double>(0, (a, t) => a + t.amount.abs());
      // 500 + 700 + 300 + 585 + 50
      expect(spend, 2135);
    });
  });

  group('insights', () {
    final summary = ExpensesSummary(
      transactions: export.transactions,
      loans: export.loans,
    ).forAnalysisPeriod(_september);
    final insights = computeExpenseInsights(
      summary,
      now: DateTime(2026, 9, 30),
    );

    test('summarises savings with a rate against income', () {
      // 10,000 from Bank + 5,000 into the Savings account + 1,000 (Eid).
      expect(insights.savings.saved, 16000);
      expect(insights.savings.withdrawn, 2000);
      expect(insights.savings.net, 14000);
      expect(insights.savings.deposits, 3);
      expect(insights.savings.rate, closeTo(14000 / 52000, 1e-9));
    });

    test('totals what you owe and are owed', () {
      final loans = insights.loans;
      expect(loans.owedToYou, 500);
      expect(loans.youOwe, 16000);
      expect(loans.net, -15500);
      expect(loans.lentCount, 1);
      expect(loans.borrowedCount, 2);
      expect(loans.oldest, DateTime(2026, 5, 10, 10));
    });

    test('counts balance corrections as a sign of missed entries', () {
      expect(insights.corrections.count, 3);
      expect(insights.corrections.net, -60);
      expect(insights.corrections.absoluteTotal, 300);
      expect(insights.corrections.suggestsMissedEntries, isTrue);
    });

    test('splits income by source', () {
      expect(insights.incomeMix.first.label, 'Salary');
      expect(insights.incomeMix.first.amount, 50000);
      expect(insights.incomeMix.last.label, 'Gifts');
    });

    test('ranks repeat places and ignores generic titles', () {
      expect(insights.merchants.single.name, 'Swapno');
      expect(insights.merchants.single.count, 2);
      expect(insights.merchants.single.total, 1200);
    });

    test('groups a recurring series regardless of amount', () {
      final pizza = summary.recurring.firstWhere(
        (r) => r.label == 'Pizza Party',
      );
      expect(pizza.cadence, 'weekly');
      expect(pizza.count, 3);
      expect(pizza.typicalAmount, -100, reason: 'median');
      expect(pizza.total, -350);
      expect(pizza.isActive(DateTime(2026, 9, 30)), isFalse);
      final eid = summary.recurring.firstWhere((r) => r.label == 'Eid');
      expect(eid.cadence, 'monthly');
      expect(eid.isActive(DateTime(2026, 9, 30)), isTrue);
    });
  });

  group('history and projection', () {
    MonthlyExpenseRow row(int month, double spend) => MonthlyExpenseRow(
      month: DateTime(2026, month),
      spend: spend,
      income: 0,
      saved: 0,
      withdrawn: 0,
      corrections: 0,
      correctionNet: 0,
    );

    test('history covers every month and fills the gaps', () {
      final history = buildMonthlyExpenseHistory(
        ExpensesSummary(transactions: export.transactions),
      );
      expect(history.first.month, DateTime(2025, 5));
      expect(history.last.month, DateTime(2026, 9));
      expect(history.length, 17);
      expect(history.firstWhere((m) => m.month == DateTime(2025, 6)).spend, 0);
      final sep = history.last;
      expect(sep.spend, 2135);
      expect(sep.income, 52000);
      expect(
        sep.saved,
        15000 + 1000,
        reason: 'bank outflow + savings inflow + Eid',
      );
    });

    test('typical month is the median of recent complete months', () {
      final history = [row(3, 100), row(4, 300), row(5, 200), row(6, 9000)];
      expect(
        typicalMonthlySpend(history, now: DateTime(2026, 7, 10)),
        250,
        reason: 'median of 100, 200, 300, 9000 is robust to the outlier',
      );
    });

    test('needs two complete months', () {
      expect(
        typicalMonthlySpend([row(5, 100)], now: DateTime(2026, 7, 1)),
        isNull,
      );
      expect(
        typicalMonthlySpend([
          row(5, 100),
          row(6, 0),
        ], now: DateTime(2026, 7, 1)),
        isNull,
        reason: 'months with no spending are not months of data',
      );
    });

    test('projects the rest of the month at a normal daily rate', () {
      final history = [row(5, 3100), row(6, 3100)];
      final projection = projectMonth(
        spentSoFar: 1000,
        history: history,
        periodStart: DateTime(2026, 7, 1),
        now: DateTime(2026, 7, 11),
      )!;
      // 3100 / 31 days = 100 a day, 20 days left.
      expect(projection.projected, closeTo(3000, 1e-9));
      expect(projection.typicalMonth, 3100);
      expect(projection.daysElapsed, 11);
    });

    test('one huge purchase does not inflate the projection', () {
      final history = [row(5, 3100), row(6, 3100)];
      final projection = projectMonth(
        spentSoFar: 60000,
        history: history,
        periodStart: DateTime(2026, 7, 1),
        now: DateTime(2026, 7, 2),
      )!;
      // Spent so far plus 29 normal days, not 60000 / 2 * 31.
      expect(projection.projected, closeTo(60000 + 2900, 1e-9));
    });

    test('is null for a month that is over', () {
      expect(
        projectMonth(
          spentSoFar: 1,
          history: [row(5, 3100), row(6, 3100)],
          periodStart: DateTime(2026, 6, 1),
          now: DateTime(2026, 7, 11),
        ),
        isNull,
      );
    });
  });

  group('recurrence rules', () {
    test('reads the cadence', () {
      expect(parseRecurrence('repeat every 1 week')!.label, 'weekly');
      expect(parseRecurrence('repeat every 1 day')!.days, 1);
      expect(parseRecurrence('repeat every 2 weeks')!.label, 'every 2 weeks');
      expect(parseRecurrence('repeat every 2 weeks')!.days, 14);
      expect(parseRecurrence('repeat every 1 month')!.label, 'monthly');
      expect(parseRecurrence('nonsense'), isNull);
      expect(parseRecurrence(null), isNull);
    });
  });

  group('loan summary', () {
    test('is empty with no loans', () {
      expect(summarizeLoans(const []).hasAny, isFalse);
    });
  });

  moneyFlowTests();
}

final _september = AnalysisPeriod(
  dataMonthStart: DateTime(2026, 9, 1),
  dataMonthEnd: DateTime(2026, 9, 30, 23, 59, 59),
  checklistMonthStart: DateTime(2026, 10, 1),
);

void moneyFlowTests() {
  group('money flow prompt text', () {
    final export = parseCashewExport(_csv);
    final summary = ExpensesSummary(
      transactions: export.transactions,
      loans: export.loans,
    ).forAnalysisPeriod(_september);
    final text = buildMoneyFlowText(
      summary,
      periodStart: _september.dataMonthStart,
      now: DateTime(2026, 10, 2),
    );

    test('explains what is not counted as spending', () {
      expect(text, startsWith('Money Flow:'));
      expect(text, contains('Not counted as spending: savings 16,000 BDT'));
      expect(text, contains('loan movements 77,216.95 BDT'));
    });

    test('reports savings, debts and corrections', () {
      expect(
        text,
        contains(
          'Savings: 16,000 BDT put aside in 3 transfers, 2,000 BDT taken out (net 27% of income)',
        ),
      );
      expect(text, contains('you owe 16,000 BDT across 2 people'));
      expect(text, contains('you are owed 500 BDT across 1 person'));
      expect(text, contains('oldest unsettled from May 2026'));
      expect(
        text,
        contains(
          'Balance corrections: 3 (net -60 BDT, 300 BDT adjusted in total)',
        ),
      );
      expect(text, contains('transactions were not recorded'));
    });

    test('lists income sources and repeat places', () {
      expect(
        text,
        contains('Income sources: Salary 50,000 BDT, Gifts 2,000 BDT'),
      );
      expect(text, contains('Most frequent places: Swapno 2× (1,200 BDT)'));
    });

    test('never names the people in a debt', () {
      for (final name in ['Siam', 'Emon', 'Saba']) {
        expect(text, isNot(contains(name)));
      }
    });

    test('is empty when there is nothing to say', () {
      expect(buildMoneyFlowText(const ExpensesSummary(transactions: [])), '');
    });

    test('lists a recurring entry once it is the only active one', () {
      expect(text, contains('Active recurring entries: 1 (Eid monthly)'));
    });
  });
}
