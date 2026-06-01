import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/analysis_month_settings_service.dart';
import '../../core/analysis_period.dart';
import '../../core/analysis_view_providers.dart';
import '../expenses/cashew_transaction.dart';
import '../calendar/calendar_event.dart';
import '../game_activity/game_activity_session.dart';
import '../health/health_service.dart';
import '../health/health_summary.dart';
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
      final period = _ref.read(analysisPeriodProvider);
      final config = await _ref.read(promptConfigProvider.future);
      final expenses = _ref.read(expensesForAnalysisProvider);
      final location = _ref.read(locationForAnalysisProvider);
      final gameActivity = _ref.read(gameActivityForAnalysisProvider);

      // Use cached calendar data; syncing here would call Google Sign-In and
      // often show the account picker on every run (google_sign_in 7.x).
      final calendar = _ref.read(calendarForAnalysisProvider);
      final monthlyHealth = await _ref.read(monthlyHealthDataProvider.future);
      final monthlySummary = MonthlyHealthSummary.fromFetch(monthlyHealth);

      final dataSnapshot = {
        'health': _healthText(monthlySummary),
        'expenses': _expensesText(expenses),
        'location': _locationText(location, period),
        'gameActivity': _gameActivityText(gameActivity),
        'calendar': _calendarText(calendar, period),
      };

      final prompt = _renderPrompt(
        config,
        dataSnapshot,
        period,
        avgSteps: monthlySummary.avgStepsPerDay.round(),
        totalRealExpenses: expenses.totalRealExpenses,
        expensesCurrency: expenses.currency,
      );
      final systemInstruction = config.composeSystemInstruction();
      final aiSettings = await _ref.read(aiSettingsProvider.future);
      final apiOutput = aiSettings.enableApiCalls
          ? await _aiClient.generate(
              settings: aiSettings,
              prompt: prompt,
              systemInstruction: systemInstruction,
            )
          : _generateInsights(
              period: period,
              monthlySummary: monthlySummary,
              monthlyHealth: monthlyHealth,
              expenses: expenses,
              location: location,
              gameActivity: gameActivity,
              calendar: calendar,
              focus: config.focus,
            );

      final now = DateTime.now();
      final monthLabel = DateFormat('MMMM yyyy').format(period.dataMonthStart);
      final result = AnalysisResult(
        id: '${now.microsecondsSinceEpoch}-${_random.nextInt(9999)}',
        createdAt: now,
        title: 'Monthly insights · $monthLabel',
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

String _renderPrompt(
  PromptConfig config,
  Map<String, String> snapshot,
  AnalysisPeriod period, {
  required int avgSteps,
  required double totalRealExpenses,
  required String expensesCurrency,
}) {
  final totalExpensesLabel =
      '${totalRealExpenses.toStringAsFixed(2)} $expensesCurrency';
  final focus = config.focus.replaceAll(
    '{{checklistMonth}}',
    period.checklistMonthLabel,
  );

  return config
      .composeTemplate()
      .replaceAll('{{focus}}', focus)
      .replaceAll('{{analysisMonth}}', period.dataRangeLabel)
      .replaceAll('{{checklistMonth}}', period.checklistMonthLabel)
      .replaceAll('{{checklistWeekCount}}', period.checklistWeekCount.toString())
      .replaceAll('{{checklistWeekSegments}}', period.checklistWeeksPromptBlock)
      .replaceAll('{{avgSteps}}', avgSteps.toString())
      .replaceAll('{{totalRealExpenses}}', totalExpensesLabel)
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

String _healthText(MonthlyHealthSummary summary) =>
    summary.toAnalysisPromptText();

String _expensesText(ExpensesSummary summary) => summary.toAnalysisPromptText();

String _locationText(LocationSummary summary, AnalysisPeriod period) =>
    summary.toAnalysisPromptText(
      dataMonthStart: period.dataMonthStart,
      dataMonthEnd: period.dataMonthEnd,
    );

String _gameActivityText(GameActivitySummary summary) =>
    summary.toAnalysisPromptText();

String _calendarText(CalendarSummary summary, AnalysisPeriod period) =>
    summary.toAnalysisPromptText();

String _generateInsights({
  required AnalysisPeriod period,
  required MonthlyHealthSummary monthlySummary,
  required MonthlyHealthFetchResult monthlyHealth,
  required ExpensesSummary expenses,
  required LocationSummary location,
  required GameActivitySummary gameActivity,
  required CalendarSummary calendar,
  required String focus,
}) {
  final lines = <String>[
    'Focus: $focus',
    'Data month: ${period.dataRangeLabel}',
    'Checklist month: ${period.checklistMonthLabel}',
    '',
    'Highlights',
  ];

  final avgSteps = monthlySummary.avgStepsPerDay.round();
  if (avgSteps > 0) {
    lines.add(
      '- Monthly average is $avgSteps steps per day (${monthlySummary.periodRangeLabel}). '
      '${avgSteps < 6000 ? 'Consider building more daily movement into next month.' : 'Good movement volume for the month.'}',
    );
  } else {
    lines.add(
      '- Health step data is missing for ${monthlySummary.periodRangeLabel}; check Samsung Health sync.',
    );
  }

  if (expenses.transactions.isNotEmpty) {
    final burn = expenses.burnRate;
    final expensePeriod = expenses.periodRangeLabel ?? period.dataRangeLabel;
    if (burn != null) {
      lines.add(
        '- Burn rate is ${(burn * 100).toStringAsFixed(1)}% for $expensePeriod. '
        '${burn > 0.9 ? 'Spending is close to income; tighten optional costs next month.' : 'Current spending is within a safer range.'}',
      );
    }
    lines.add(
      '- Net surplus is ${expenses.netSurplus.toStringAsFixed(2)} ${expenses.currency} ($expensePeriod).',
    );
  } else {
    lines.add(
      '- Expense data is not loaded for ${period.dataRangeLabel}; import your CSV for money insights.',
    );
  }

  final monthBikes = location
      .activitiesInRange(period.dataMonthStart, period.dataMonthEnd)
      .where(
        (activity) => activity.isMotorcycling && activity.distanceMeters > 0,
      )
      .toList();
  if (monthBikes.isNotEmpty) {
    final km =
        (monthBikes.fold<double>(
                  0,
                  (sum, activity) => sum + activity.distanceMeters,
                ) /
                1000)
            .toStringAsFixed(2);
    lines.add(
      '- Motorcycle distance is $km km across ${monthBikes.length} timeline segments.',
    );
  } else {
    lines.add(
      '- Location timeline has no motorcycle segments for ${period.dataRangeLabel}.',
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
      '- Game activity data is not loaded for ${period.dataRangeLabel}; import your CSV for leisure insights.',
    );
  }

  if (calendar.events.isNotEmpty) {
    final holidayNote = calendar.holidayGroupCount > 0
        ? ', including ${calendar.holidayGroupCount} Bangladesh public holidays '
            '(${calendar.holidayCount} days)'
        : '';
    lines.add(
      '- Calendar has ${calendar.events.length} events in scope '
      '(${calendar.upcomingEvents.length} upcoming$holidayNote).',
    );
  } else {
    lines.add(
      '- Google Calendar is not connected; sync your schedule for planning insights.',
    );
  }

  lines
    ..add('')
    ..add('Next actions (${period.checklistMonthLabel})')
    ..add(
      '- Set one health target, one spending cap, and one schedule habit for ${period.checklistMonthLabel}.',
    )
    ..add(
      '- Re-run analysis after the month ends to refresh patterns and the next checklist.',
    );

  if (!monthlyHealth.hasData) {
    lines
      ..add('')
      ..add(
        'Note: No Samsung Health data in ${monthlySummary.periodRangeLabel}; open Samsung Health to sync via Health Connect.',
      );
  }

  return lines.join('\n');
}
