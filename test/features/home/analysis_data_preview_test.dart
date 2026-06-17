import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/location/timeline_activity.dart';

void main() {
  final period = AnalysisPeriod.forDataMonth(DateTime(2026, 5, 1));

  test('buildAnalysisRunPreview marks empty sources and counts loaded ones', () {
    final preview = buildAnalysisRunPreview(
      period: period,
      healthFetch: MonthlyHealthFetchResult.empty(period: period),
      healthLoading: false,
      expenses: const ExpensesSummary(transactions: []),
      location: const LocationSummary(activities: []),
      gameActivity: const GameActivitySummary(sessions: []),
      calendar: const CalendarSummary(events: []),
      insightEngineLabel: 'On-device summary',
    );

    expect(preview.hasAnyData, isFalse);
    expect(preview.loadedSourceCount, 0);
    expect(preview.sources, hasLength(5));
    expect(preview.sources.every((s) => !s.hasData), isTrue);
  });

  test('buildAnalysisRunPreview summarizes expenses in analysis month', () {
    final preview = buildAnalysisRunPreview(
      period: period,
      healthFetch: null,
      healthLoading: false,
      expenses: ExpensesSummary(
        transactions: [
          CashewTransaction(
            account: 'Bank',
            amount: -100,
            currency: 'BDT',
            date: DateTime(2026, 5, 10),
            isIncome: false,
            category: 'Food',
            title: 'Lunch',
          ),
        ],
      ),
      location: const LocationSummary(activities: []),
      gameActivity: const GameActivitySummary(sessions: []),
      calendar: const CalendarSummary(events: []),
      insightEngineLabel: 'Cloud AI',
    );

    expect(preview.loadedSourceCount, 1);
    final expenses = preview.sources.firstWhere(
      (s) => s.id == AnalysisDataSourceId.expenses,
    );
    expect(expenses.hasData, isTrue);
    expect(expenses.detail, contains('1 transactions'));
    expect(expenses.detail, contains('100'));
  });

  test('buildAnalysisRunPreview derives previous spend from CSV source', () {
    final full = ExpensesSummary(
      transactions: [
        CashewTransaction(
          account: 'Bank',
          amount: -400,
          currency: 'BDT',
          date: DateTime(2026, 4, 20),
          isIncome: false,
          category: 'Food',
          title: 'Old lunch',
        ),
        CashewTransaction(
          account: 'Bank',
          amount: -100,
          currency: 'BDT',
          date: DateTime(2026, 5, 10),
          isIncome: false,
          category: 'Food',
          title: 'Lunch',
        ),
      ],
    );

    final preview = buildAnalysisRunPreview(
      period: period,
      healthFetch: null,
      healthLoading: false,
      expenses: full.forAnalysisPeriod(period),
      expensesSource: full,
      location: const LocationSummary(activities: []),
      gameActivity: const GameActivitySummary(sessions: []),
      calendar: const CalendarSummary(events: []),
      insightEngineLabel: 'Cloud AI',
    );

    final expenses = preview.sources.firstWhere(
      (s) => s.id == AnalysisDataSourceId.expenses,
    );
    expect(expenses.promptText, contains('- Previous month spend (April 2026): 400.00 BDT'));
  });

  test('buildAnalysisRunPreview includes monthly budget from personal information', () {
    final preview = buildAnalysisRunPreview(
      period: period,
      healthFetch: null,
      healthLoading: false,
      expenses: ExpensesSummary(
        transactions: [
          CashewTransaction(
            account: 'Bank',
            amount: -10000,
            currency: 'BDT',
            date: DateTime(2026, 5, 10),
            isIncome: false,
            category: 'Food',
            title: 'Lunch',
          ),
        ],
      ),
      location: const LocationSummary(activities: []),
      gameActivity: const GameActivitySummary(sessions: []),
      calendar: const CalendarSummary(events: []),
      insightEngineLabel: 'Cloud AI',
      monthlyIncomeBdt: '80000',
      monthlyBudgetBdt: '50000',
    );

    final expenses = preview.sources.firstWhere(
      (s) => s.id == AnalysisDataSourceId.expenses,
    );
    expect(expenses.promptText, contains('- Monthly budget: 50,000'));
    expect(expenses.promptText, contains('- Monthly baseline: 80,000 BDT'));
  });

  test('AnalysisSourceSelection tracks included domains', () {
    final all = AnalysisSourceSelection.all();
    expect(all.includes(AnalysisDataSourceId.health), isTrue);

    final partial = AnalysisSourceSelection({
      AnalysisDataSourceId.expenses,
      AnalysisDataSourceId.calendar,
    });
    expect(partial.includes(AnalysisDataSourceId.health), isFalse);
    expect(partial.includes(AnalysisDataSourceId.expenses), isTrue);
    expect(partial.isEmpty, isFalse);
    expect(AnalysisSourceSelection({}).isEmpty, isTrue);
  });
}
