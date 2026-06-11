import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/features/analysis/analysis_kind.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/analysis_reports_storage.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/core/app_lifecycle_service.dart';
import 'package:personal/features/results/ai_client.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/core/data_folder_settings_service.dart';

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

  Future<String> _generateAiOutput({
    required AiSettings aiSettings,
    required String prompt,
    required String systemInstruction,
  }) {
    return _aiClient.generate(
      settings: aiSettings,
      prompt: prompt,
      systemInstruction: systemInstruction,
      waitForResume: () =>
          _ref.read(appLifecycleProvider.notifier).waitUntilResumed(),
    );
  }

  Future<AnalysisResult?> runAnalysis(AnalysisSourceSelection selection) async {
    if (state.isRunning || selection.isEmpty) return null;

    final settings = await _ref.read(dataFolderSettingsProvider.future);
    if (!settings.hasFolder) {
      state = state.copyWith(lastError: missingReportsFolderMessage);
      return null;
    }

    final config = await _ref.read(promptConfigProvider.future);
    if (!config.isPersonalInfoComplete) {
      state = state.copyWith(lastError: missingPersonalInfoMessage);
      return null;
    }

    state = state.copyWith(isRunning: true, clearError: true);

    try {
      final period = _ref.read(analysisPeriodProvider);
      final expenses = _ref.read(expensesForAnalysisProvider);
      final location = _ref.read(locationForAnalysisProvider);
      final gameActivity = _ref.read(gameActivityForAnalysisProvider);

      final calendar = _ref.read(calendarForAnalysisProvider);
      final monthlyHealth = await _ref.read(monthlyHealthDataProvider.future);
      final monthlySummary = MonthlyHealthSummary.fromFetch(monthlyHealth);

      final dataSnapshot = _buildDataSnapshot(
        selection: selection,
        monthlySummary: monthlySummary,
        expenses: expenses,
        location: location,
        gameActivity: gameActivity,
        calendar: calendar,
        period: period,
        workAddress: config.workAddress,
        workHours: config.workHours,
      );

      final prompt = _renderPrompt(
        config,
        dataSnapshot,
        period,
        totalRealExpenses: selection.includes(AnalysisDataSourceId.expenses)
            ? expenses.totalRealExpenses
            : 0,
        expensesCurrency: selection.includes(AnalysisDataSourceId.expenses)
            ? expenses.currency
            : '',
      );
      final systemInstruction = config.composeSystemInstruction();
      final aiSettings = await _ref.read(aiSettingsProvider.future);
      final usedApi = aiSettings.enableApiCalls;
      final apiOutput = usedApi
          ? await _generateAiOutput(
              aiSettings: aiSettings,
              prompt: prompt,
              systemInstruction: systemInstruction,
            )
          : _generateInsights(
              period: period,
              selection: selection,
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
        title: '${AnalysisKind.monthlyInsights.resultTitlePrefix} · $monthLabel',
        prompt: prompt,
        output: apiOutput,
        dataSnapshot: dataSnapshot,
        dataMonthStart: period.dataMonthStart,
        aiProvider: usedApi ? aiSettings.provider.name : 'local',
        aiModel: usedApi
            ? (aiSettings.provider == AiProvider.openai
                ? aiSettings.openAiModel
                : aiSettings.geminiModel)
            : null,
        analysisKind: AnalysisKind.monthlyInsights,
      );
      await _ref.read(analysisResultsProvider.notifier).addResult(result);

      state = state.copyWith(
        isRunning: false,
        clearError: true,
        lastRunAt: now,
      );
      return result;
    } catch (error) {
      state = state.copyWith(isRunning: false, lastError: error.toString());
      return null;
    }
  }
}

const _excludedFromRunMessage = 'Excluded from this analysis run.';

Map<String, String> _buildDataSnapshot({
  required AnalysisSourceSelection selection,
  required MonthlyHealthSummary monthlySummary,
  required ExpensesSummary expenses,
  required LocationSummary location,
  required GameActivitySummary gameActivity,
  required CalendarSummary calendar,
  required AnalysisPeriod period,
  String workAddress = '',
  String workHours = '',
}) {
  return {
    'health': selection.includes(AnalysisDataSourceId.health)
        ? selection.promptOverrides[AnalysisDataSourceId.health] ??
            _healthText(monthlySummary)
        : _excludedFromRunMessage,
    'expenses': selection.includes(AnalysisDataSourceId.expenses)
        ? selection.promptOverrides[AnalysisDataSourceId.expenses] ??
            _expensesText(expenses)
        : _excludedFromRunMessage,
    'expenseCategories': selection.includes(AnalysisDataSourceId.expenses)
        ? expenses.toFinancialContextCategoriesBlock()
        : '* (expenses excluded from this run)',
    'location': selection.includes(AnalysisDataSourceId.location)
        ? selection.promptOverrides[AnalysisDataSourceId.location] ??
            _locationText(
              location,
              period,
              workAddress: workAddress,
              workHours: workHours,
            )
        : _excludedFromRunMessage,
    'gameActivity': selection.includes(AnalysisDataSourceId.gameActivity)
        ? selection.promptOverrides[AnalysisDataSourceId.gameActivity] ??
            _gameActivityText(gameActivity)
        : _excludedFromRunMessage,
    'calendar': selection.includes(AnalysisDataSourceId.calendar)
        ? selection.promptOverrides[AnalysisDataSourceId.calendar] ??
            _calendarText(calendar, period)
        : _excludedFromRunMessage,
  };
}

String _renderPrompt(
  PromptConfig config,
  Map<String, String> snapshot,
  AnalysisPeriod period, {
  required double totalRealExpenses,
  required String expensesCurrency,
}) {
  final totalExpensesLabel =
      '${totalRealExpenses.toStringAsFixed(2)} $expensesCurrency';

  return _applyPromptPlaceholders(
    config.composeTemplate(),
    snapshot: snapshot,
    period: period,
    focus: config.focus,
    totalExpensesLabel: totalExpensesLabel,
  );
}

String _applyPromptPlaceholders(
  String template, {
  required Map<String, String> snapshot,
  required AnalysisPeriod period,
  required String focus,
  required String totalExpensesLabel,
}) {
  return template
      .replaceAll('{{focus}}', focus)
      .replaceAll('{{analysisMonth}}', period.dataRangeLabel)
      .replaceAll('{{totalRealExpenses}}', totalExpensesLabel)
      .replaceAll('{{health}}', snapshot['health'] ?? 'No health data')
      .replaceAll('{{expenses}}', snapshot['expenses'] ?? 'No expense data')
      .replaceAll(
        '{{expenseCategories}}',
        snapshot['expenseCategories'] ?? '* (no expense categories available)',
      )
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

String _locationText(
  LocationSummary summary,
  AnalysisPeriod period, {
  String workAddress = '',
  String workHours = '',
}) =>
    summary.toAnalysisPromptText(
      dataMonthStart: period.dataMonthStart,
      dataMonthEnd: period.dataMonthEnd,
      workAddress: workAddress,
      workHours: workHours,
    );

String _gameActivityText(GameActivitySummary summary) =>
    summary.toAnalysisPromptText();

String _calendarText(CalendarSummary summary, AnalysisPeriod period) =>
    summary.toAnalysisPromptText();

String _generateInsights({
  required AnalysisPeriod period,
  required AnalysisSourceSelection selection,
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
    '',
    '### **Patterns & Anomalies**',
    '',
  ];

  if (selection.includes(AnalysisDataSourceId.health)) {
    if (monthlyHealth.hasData) {
      lines.add(
        '- Sleep data available for ${monthlySummary.periodRangeLabel}.',
      );
    } else {
      lines.add(
        '- Health data is missing for ${monthlySummary.periodRangeLabel}; check Samsung Health sync.',
      );
    }
  }

  if (selection.includes(AnalysisDataSourceId.expenses) &&
      expenses.transactions.isNotEmpty) {
    final burn = expenses.burnRate;
    final expensePeriod = expenses.periodRangeLabel ?? period.dataRangeLabel;
    if (burn != null) {
      lines.add(
        '- Burn rate is ${(burn * 100).toStringAsFixed(1)}% for $expensePeriod. '
        '${burn > 0.9 ? 'Spending is close to income; tighten optional costs.' : 'Current spending is within a safer range.'}',
      );
    }
    lines.add(
      '- Net surplus is ${expenses.netSurplus.toStringAsFixed(2)} ${expenses.currency} ($expensePeriod).',
    );
  } else if (selection.includes(AnalysisDataSourceId.expenses)) {
    lines.add(
      '- Expense data is not loaded for ${period.dataRangeLabel}; import your CSV for money insights.',
    );
  }

  if (selection.includes(AnalysisDataSourceId.location)) {
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
  }

  if (selection.includes(AnalysisDataSourceId.gameActivity) &&
      gameActivity.sessions.isNotEmpty) {
    lines.add(
      '- Gaming totals ${gameActivity.sessions.length} sessions '
      '(${GameActivitySummary.formatPromptDuration(gameActivity.totalPlayTime)}) '
      'across ${gameActivity.uniqueGameCount} titles.',
    );
  } else if (selection.includes(AnalysisDataSourceId.gameActivity)) {
    lines.add(
      '- Game activity data is not loaded for ${period.dataRangeLabel}; import your CSV for leisure insights.',
    );
  }

  if (selection.includes(AnalysisDataSourceId.calendar) &&
      calendar.events.isNotEmpty) {
    final holidayNote = calendar.holidayGroupCount > 0
        ? ', including ${calendar.holidayGroupCount} Bangladesh public holidays '
            '(${calendar.holidayCount} days)'
        : '';
    lines.add(
      '- Calendar has ${calendar.events.length} events in scope '
      '(${calendar.upcomingEvents.length} upcoming$holidayNote).',
    );
  } else if (selection.includes(AnalysisDataSourceId.calendar)) {
    lines.add(
      '- Google Calendar is not connected; sync your schedule for planning insights.',
    );
  }

  if (selection.includes(AnalysisDataSourceId.health) && !monthlyHealth.hasData) {
    lines
      ..add('')
      ..add(
        'Note: No Samsung Health data in ${monthlySummary.periodRangeLabel}; open Samsung Health to sync via Health Connect.',
      );
  }

  return lines.join('\n');
}
