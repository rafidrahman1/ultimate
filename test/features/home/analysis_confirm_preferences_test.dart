import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/home/analysis_confirm_preferences_service.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/location/timeline_activity.dart';

void main() {
  final period = AnalysisPeriod.forDataMonth(DateTime(2026, 5, 1));

  AnalysisRunPreview buildPreview({String expensePrompt = 'expense prompt'}) {
    return buildAnalysisRunPreview(
      period: period,
      healthFetch: MonthlyHealthFetchResult.empty(period: period),
      healthLoading: false,
      expenses: ExpensesSummary(
        transactions: [
          CashewTransaction(
            account: 'Bank',
            amount: -50,
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
      insightEngineLabel: 'On-device summary',
    );
  }

  test('resolveAnalysisConfirmPreferences restores matching overrides', () {
    final preview = buildPreview();
    final expenses = preview.sources
        .firstWhere((s) => s.id == AnalysisDataSourceId.expenses);

    final stored = AnalysisConfirmPreferencesStored(
      periodStart: period.dataMonthStart,
      overrides: {
        AnalysisDataSourceId.expenses: AnalysisConfirmSourceOverride(
          baseFingerprint: promptTextFingerprint(expenses.promptText),
          text: 'edited expenses',
        ),
      },
      included: {AnalysisDataSourceId.expenses},
    );

    final resolved = resolveAnalysisConfirmPreferences(
      preview: preview,
      stored: stored,
    );

    expect(
      resolved.promptOverrides[AnalysisDataSourceId.expenses],
      'edited expenses',
    );
    expect(resolved.included, {AnalysisDataSourceId.expenses});
  });

  test('resolveAnalysisConfirmPreferences drops overrides after data resync', () {
    final preview = buildPreview();
    final expenses = preview.sources
        .firstWhere((s) => s.id == AnalysisDataSourceId.expenses);

    final stored = AnalysisConfirmPreferencesStored(
      periodStart: period.dataMonthStart,
      overrides: {
        AnalysisDataSourceId.expenses: AnalysisConfirmSourceOverride(
          baseFingerprint: promptTextFingerprint('old synced prompt'),
          text: 'edited expenses',
        ),
      },
    );

    final resolved = resolveAnalysisConfirmPreferences(
      preview: preview,
      stored: stored,
    );

    expect(resolved.promptOverrides, isEmpty);
    expect(
      promptTextFingerprint(expenses.promptText),
      isNot(promptTextFingerprint('old synced prompt')),
    );
  });

  test('resolveAnalysisConfirmPreferences ignores other analysis months', () {
    final preview = buildPreview();
    final expenses = preview.sources
        .firstWhere((s) => s.id == AnalysisDataSourceId.expenses);

    final stored = AnalysisConfirmPreferencesStored(
      periodStart: DateTime(2026, 4, 1),
      overrides: {
        AnalysisDataSourceId.expenses: AnalysisConfirmSourceOverride(
          baseFingerprint: promptTextFingerprint(expenses.promptText),
          text: 'edited expenses',
        ),
      },
    );

    final resolved = resolveAnalysisConfirmPreferences(
      preview: preview,
      stored: stored,
    );

    expect(resolved.promptOverrides, isEmpty);
  });
}
