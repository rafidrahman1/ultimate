import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/results/stable_month_detection.dart';

DailySleepEntry _night(
  int day, {
  required int hours,
  required int minutes,
}) {
  return DailySleepEntry(
    wakeDate: DateTime(2026, 5, day),
    session: SleepSummary(
      duration: Duration(hours: hours, minutes: minutes),
      startTime: DateTime(2026, 5, day - 1, 23, 0),
      endTime: DateTime(2026, 5, day, 7, 0),
    ),
  );
}

ExpensesSummary _expenses({
  double income = 50000,
  List<({String category, double amount})> spends = const [],
}) {
  return ExpensesSummary(
    transactions: [
      CashewTransaction(
        account: 'Bank',
        amount: income,
        currency: 'BDT',
        date: DateTime(2026, 5, 1),
        isIncome: true,
        category: 'Cash In',
      ),
      for (final spend in spends)
        CashewTransaction(
          account: 'Bank',
          amount: -spend.amount,
          currency: 'BDT',
          date: DateTime(2026, 5, 10),
          isIncome: false,
          subcategory: spend.category,
        ),
    ],
  );
}

void main() {
  test('classifies stable month when all criteria pass', () {
    final assessment = evaluateStableMonth(
      selection: AnalysisSourceSelection.all(),
      dailySleep: [
        for (var day = 1; day <= 28; day++)
          _night(day, hours: 7, minutes: 15),
        _night(29, hours: 5, minutes: 30),
        _night(30, hours: 5, minutes: 45),
      ],
      expenses: _expenses(
        spends: [
          (category: 'Groceries', amount: 3000),
          (category: 'Snacks', amount: 1500),
        ],
      ),
    );

    expect(assessment.canEvaluate, isTrue);
    expect(assessment.isStable, isTrue);
    expect(assessment.shortSleepNights, 2);
    expect(assessment.hasSevereAnomalyCluster, isFalse);

    final text = buildHealthyMonthDetectionText(assessment);
    expect(text, contains('Month: Stable'));
    expect(text, contains('Short sleep nights: 2'));
    expect(text, isNot(contains('Prioritize')));
  });

  test('classifies active month when short sleep nights exceed threshold', () {
    final assessment = evaluateStableMonth(
      selection: AnalysisSourceSelection.all(),
      dailySleep: [
        for (var day = 1; day <= 27; day++)
          _night(day, hours: 7, minutes: 15),
        _night(28, hours: 5, minutes: 30),
        _night(29, hours: 5, minutes: 45),
        _night(30, hours: 5, minutes: 20),
      ],
      expenses: _expenses(spends: [(category: 'Groceries', amount: 2000)]),
    );

    expect(assessment.isStable, isFalse);
    expect(assessment.shortSleepNights, 3);

    final text = buildHealthyMonthDetectionText(assessment);
    expect(text, contains('Month: Active'));
  });

  test('classifies active month when expense category exceeds 10% income', () {
    final assessment = evaluateStableMonth(
      selection: AnalysisSourceSelection.all(),
      dailySleep: [
        for (var day = 1; day <= 30; day++)
          _night(day, hours: 7, minutes: 15),
      ],
      expenses: _expenses(
        spends: [(category: 'Electronics', amount: 6000)],
      ),
    );

    expect(assessment.isStable, isFalse);
  });

  test('classifies active month when severe sleep cluster is present', () {
    final assessment = evaluateStableMonth(
      selection: AnalysisSourceSelection.all(),
      dailySleep: [
        for (var day = 1; day <= 20; day++)
          _night(day, hours: 7, minutes: 15),
        for (var day = 26; day <= 31; day++)
          _night(day, hours: 4, minutes: 30),
      ],
      expenses: _expenses(spends: [(category: 'Groceries', amount: 2000)]),
    );

    expect(assessment.isStable, isFalse);
    expect(assessment.hasSevereAnomalyCluster, isTrue);
  });

  test('shows top category as share of spending in derived metrics text', () {
    final assessment = evaluateStableMonth(
      selection: AnalysisSourceSelection.all(),
      dailySleep: [
        for (var day = 1; day <= 30; day++)
          _night(day, hours: 7, minutes: 15),
      ],
      expenses: _expenses(
        spends: [
          (category: 'Restaurant', amount: 3350),
          (category: 'Fuel', amount: 1759.85),
        ],
      ),
    );

    final text = buildHealthyMonthDetectionText(assessment);
    expect(text, contains('Top category: Restaurant · 65.6% of spending'));
  });

  test('cannot evaluate without health and expenses', () {
    final assessment = evaluateStableMonth(
      selection: const AnalysisSourceSelection({AnalysisDataSourceId.health}),
      dailySleep: [
        _night(1, hours: 7, minutes: 15),
      ],
    );

    expect(assessment.canEvaluate, isFalse);
    expect(assessment.isStable, isFalse);
    expect(
      buildHealthyMonthDetectionText(assessment),
      contains('n/a (health + expenses required)'),
    );
  });
}
