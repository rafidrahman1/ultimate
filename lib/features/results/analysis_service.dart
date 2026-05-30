import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../expenses/cashew_transaction.dart';
import '../calendar/calendar_event.dart';
import '../calendar/calendar_service.dart';
import '../calendar/calendar_settings_service.dart';
import '../game_activity/game_activity_session.dart';
import '../game_activity/game_activity_service.dart';
import '../expenses/expenses_service.dart';
import '../health/health_service.dart';
import '../health/health_summary.dart';
import '../location/location_service.dart';
import '../location/timeline_activity.dart';
import '../prompts/prompt_config_service.dart';
import '../settings/ai_settings_service.dart';
import 'ai_client.dart';
import 'results_service.dart';

class AnalysisRunState {
  const AnalysisRunState({
    this.isRunning = false,
    this.lastError,
    this.lastRunAt,
  });

  final bool isRunning;
  final String? lastError;
  final DateTime? lastRunAt;

  AnalysisRunState copyWith({
    bool? isRunning,
    String? lastError,
    bool clearError = false,
    DateTime? lastRunAt,
  }) {
    return AnalysisRunState(
      isRunning: isRunning ?? this.isRunning,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastRunAt: lastRunAt ?? this.lastRunAt,
    );
  }
}

final analysisRunProvider =
    StateNotifierProvider<AnalysisRunController, AnalysisRunState>(
      (ref) => AnalysisRunController(ref),
    );

class AnalysisRunController extends StateNotifier<AnalysisRunState> {
  AnalysisRunController(this._ref) : super(const AnalysisRunState());

  final Ref _ref;
  final Random _random = Random();
  final AiClient _aiClient = const AiClient();

  Future<void> runAnalysis() async {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true, clearError: true);

    try {
      final config = await _ref.read(promptConfigProvider.future);
      final expenses = _ref.read(expensesSummaryProvider);
      final location = _ref.read(locationSummaryProvider);
      final gameActivity = _ref.read(gameActivitySummaryProvider);

      final calendarSettings = await _ref.read(calendarSettingsProvider.future);
      if (calendarSettings.isConnected) {
        try {
          await _ref.read(calendarSummaryProvider.notifier).loadAuto();
        } catch (_) {
          // Keep the last synced calendar if refresh fails mid-analysis.
        }
      }
      final calendar = _ref.read(calendarSummaryProvider);
      final weeklyHealth = await _ref.read(weeklyHealthDataProvider.future);
      final weeklySummary = WeeklyHealthSummary.fromWeeklyFetch(weeklyHealth);

      final dataSnapshot = {
        'health': _healthText(weeklySummary),
        'expenses': _expensesText(expenses),
        'location': _locationText(location),
        'gameActivity': _gameActivityText(gameActivity),
        'calendar': _calendarText(calendar),
      };

      final prompt = _renderPrompt(config, dataSnapshot);
      final systemInstruction = config.composeSystemInstruction();
      final aiSettings = await _ref.read(aiSettingsProvider.future);
      final apiOutput = aiSettings.enableApiCalls
          ? await _aiClient.generate(
              settings: aiSettings,
              prompt: prompt,
              systemInstruction: systemInstruction,
            )
          : _generateInsights(
              weeklySummary: weeklySummary,
              weeklyHealth: weeklyHealth,
              expenses: expenses,
              location: location,
              gameActivity: gameActivity,
              calendar: calendar,
              focus: config.focus,
            );

      final now = DateTime.now();
      final result = AnalysisResult(
        id: '${now.microsecondsSinceEpoch}-${_random.nextInt(9999)}',
        createdAt: now,
        title: 'Personal insights (${now.year}-${now.month}-${now.day})',
        prompt: prompt,
        output: apiOutput,
        dataSnapshot: dataSnapshot,
      );
      await _ref.read(analysisResultsProvider.notifier).addResult(result);

      state = state.copyWith(
        isRunning: false,
        clearError: true,
        lastRunAt: now,
      );
    } catch (error) {
      state = state.copyWith(isRunning: false, lastError: error.toString());
    }
  }
}

String _renderPrompt(PromptConfig config, Map<String, String> snapshot) {
  return config
      .composeTemplate()
      .replaceAll('{{focus}}', config.focus)
      .replaceAll('{{health}}', snapshot['health'] ?? 'No health data')
      .replaceAll('{{expenses}}', snapshot['expenses'] ?? 'No expense data')
      .replaceAll('{{location}}', snapshot['location'] ?? 'No location data')
      .replaceAll(
        '{{gameActivity}}',
        snapshot['gameActivity'] ?? 'No game activity data',
      )
      .replaceAll(
        '{{calendar}}',
        snapshot['calendar'] ?? 'No calendar data',
      );
}

String _healthText(WeeklyHealthSummary summary) =>
    summary.toAnalysisPromptText();

String _expensesText(ExpensesSummary summary) => summary.toAnalysisPromptText();

String _locationText(LocationSummary summary) => summary.toAnalysisPromptText();

String _gameActivityText(GameActivitySummary summary) =>
    summary.toAnalysisPromptText();

String _calendarText(CalendarSummary summary) => summary.toAnalysisPromptText();

String _generateInsights({
  required WeeklyHealthSummary weeklySummary,
  required WeeklyHealthFetchResult weeklyHealth,
  required ExpensesSummary expenses,
  required LocationSummary location,
  required GameActivitySummary gameActivity,
  required CalendarSummary calendar,
  required String focus,
}) {
  final lines = <String>['Focus: $focus', '', 'Highlights'];

  final avgSteps = weeklySummary.avgStepsPerDay.round();
  if (avgSteps > 0) {
    lines.add(
      '- Weekly average is $avgSteps steps per day (${weeklySummary.periodRangeLabel}). '
      '${avgSteps < 6000 ? 'Consider one extra 25-30 minute walk on low days.' : 'Good movement volume for the week.'}',
    );
  } else {
    lines.add(
      '- Health step data is missing for ${weeklySummary.periodRangeLabel}; check Samsung Health sync.',
    );
  }

  if (expenses.transactions.isNotEmpty) {
    final burn = expenses.burnRate;
    final expensePeriod = expenses.periodRangeLabel ?? 'imported transactions';
    if (burn != null) {
      lines.add(
        '- Burn rate is ${(burn * 100).toStringAsFixed(1)}% for $expensePeriod. '
        '${burn > 0.9 ? 'Spending is close to income; reduce optional costs this week.' : 'Current spending is within a safer range.'}',
      );
    }
    lines.add(
      '- Net surplus is ${expenses.netSurplus.toStringAsFixed(2)} ${expenses.currency} ($expensePeriod).',
    );
  } else {
    lines.add(
      '- Expense data is not loaded; import your CSV for money insights.',
    );
  }

  if (location.motorcyclingActivities.isNotEmpty) {
    lines.add(
      '- Motorcycle distance is ${location.motorcycleDistanceKm.toStringAsFixed(2)} km '
      'across ${location.motorcyclingActivities.length} timeline segments.',
    );
  } else {
    lines.add(
      '- Location timeline is not loaded or has no motorcycle segments yet.',
    );
  }

  if (gameActivity.sessions.isNotEmpty) {
    lines.add(
      '- Gaming totals ${gameActivity.sessions.length} sessions '
      '(${GameActivitySummary.formatPromptDuration(gameActivity.totalPlayTime)}) '
      'across ${gameActivity.uniqueGameCount} titles.',
    );
  } else {
    lines.add(
      '- Game activity data is not loaded; import your CSV for leisure insights.',
    );
  }

  if (calendar.events.isNotEmpty) {
    final holidayNote = calendar.holidayGroupCount > 0
        ? ', including ${calendar.holidayGroupCount} Bangladesh public holidays '
            '(${calendar.holidayCount} days)'
        : '';
    lines.add(
      '- Calendar has ${calendar.events.length} events synced '
      '(${calendar.upcomingEvents.length} upcoming$holidayNote).',
    );
  } else {
    lines.add(
      '- Google Calendar is not connected; sync your schedule for planning insights.',
    );
  }

  lines
    ..add('')
    ..add('Next actions (7 days)')
    ..add(
      '- Set one health target (steps/sleep), one spending cap, and review progress after your next analysis run.',
    )
    ..add(
      '- Re-run analysis after importing fresh data to track trend changes in results history.',
    );

  if (!weeklyHealth.hasData) {
    lines
      ..add('')
      ..add(
        'Note: No Samsung Health data in ${weeklySummary.periodRangeLabel}; open Samsung Health to sync via Health Connect.',
      );
  }

  return lines.join('\n');
}
