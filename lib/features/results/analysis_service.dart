import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/features/analysis/analysis_kind.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/analysis_result_period.dart';
import 'package:personal/features/analysis/analysis_reports_storage.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/analysis/period_comparison.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/features/game_activity/game_activity_service.dart';
import 'package:personal/features/location/location_service.dart';
import 'package:personal/features/location/work_arrival_stats.dart';
import 'package:personal/features/results/goal_tracking_builder.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/location/mobility_prompt_builder.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/progress_review/progress_review_evaluation.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/prompts/prompt_template_sections.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/core/app_lifecycle_service.dart';
import 'package:personal/features/results/ai_client.dart';
import 'package:personal/features/results/analysis_checklist_builder.dart';
import 'package:personal/features/results/checklist_prompt_builder.dart';
import 'package:personal/features/results/derived_metrics_builder.dart';
import 'package:personal/features/results/insight_checklist_service.dart';
import 'package:personal/features/results/insights_parser.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/core/data_folder_settings_service.dart';
import 'package:personal/features/results/weekly_checklist_verification_parser.dart';
import 'package:personal/features/results/weekly_checklist_verification_prompt.dart';
import 'package:personal/features/results/selected_checklist_result_service.dart';
import 'package:personal/features/results/future_event_coverage_service.dart';
import 'package:personal/features/calendar/calendar_service.dart';

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
      final calendarUpcoming = _ref.read(calendarForDisplayProvider);
      final monthlyHealth = await _ref.read(monthlyHealthDataProvider.future);
      final monthlySummary = MonthlyHealthSummary.fromFetch(monthlyHealth);

      final snapshotContext = await loadAnalysisSnapshotContext(
        _ref,
        period: period,
        selection: selection,
        config: config,
        calendar: calendar,
      );

      final dataSnapshot = _buildDataSnapshot(
        selection: selection,
        monthlySummary: monthlySummary,
        expenses: expenses,
        location: location,
        gameActivity: gameActivity,
        calendar: calendar,
        calendarUpcomingSource: calendarUpcoming,
        period: period,
        workAddress: config.workAddress,
        workHours: config.workHours,
        weekendDays: config.weekendDays,
        context: snapshotContext,
      );

      final prompt = _renderPrompt(
        config,
        dataSnapshot,
        period,
        selection: selection,
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
      var apiOutput = usedApi
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

      if (usedApi) {
        apiOutput = await ensureFutureEventCoverageInOutput(
          output: apiOutput,
          period: period,
          calendarUpcoming: calendarUpcoming,
          selection: selection,
          config: config,
          aiSettings: aiSettings,
          generate: ({
            required settings,
            required prompt,
            required systemInstruction,
          }) =>
              _generateAiOutput(
                aiSettings: settings,
                prompt: prompt,
                systemInstruction: systemInstruction,
              ),
        );
      }

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
      if (InsightsReportParser.parse(apiOutput).actions.isNotEmpty) {
        await _ref
            .read(selectedChecklistResultIdProvider.notifier)
            .select(result.id);
      }

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

  Future<AnalysisResult?> runProgressReview({
    required AnalysisSourceSelection selection,
    required AnalysisResult checklistSource,
  }) async {
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

    final parsedChecklist = InsightsReportParser.parse(checklistSource.output);
    if (parsedChecklist.actions.isEmpty) {
      state = state.copyWith(
        lastError: 'Selected report has no checklist actions to review.',
      );
      return null;
    }

    state = state.copyWith(isRunning: true, clearError: true);

    try {
      final period = _ref.read(analysisPeriodProvider);
      final checklistPeriod = checklistSource.analysisPeriod;
      final expenses = _ref.read(expensesForAnalysisProvider);
      final location = _ref.read(locationForAnalysisProvider);
      final gameActivity = _ref.read(gameActivityForAnalysisProvider);
      final calendar = _ref.read(calendarForAnalysisProvider);
      final calendarUpcoming = _ref.read(calendarForDisplayProvider);
      final monthlyHealth = await _ref.read(monthlyHealthDataProvider.future);
      final monthlySummary = MonthlyHealthSummary.fromFetch(monthlyHealth);

      final completion = await loadChecklistCompletionForResult(
        checklistSource.id,
        parsedChecklist.checklistWeekCount,
      );

      final snapshotContext = await loadAnalysisSnapshotContext(
        _ref,
        period: period,
        selection: selection,
        config: config,
        calendar: calendar,
      );

      final dataSnapshot = _buildDataSnapshot(
        selection: selection,
        monthlySummary: monthlySummary,
        expenses: expenses,
        location: location,
        gameActivity: gameActivity,
        calendar: calendar,
        calendarUpcomingSource: calendarUpcoming,
        period: period,
        workAddress: config.workAddress,
        workHours: config.workHours,
        weekendDays: config.weekendDays,
        context: snapshotContext,
      );

      final checklistTargets = buildChecklistTargetsPromptBlock(
        report: parsedChecklist,
        checklistPeriod: checklistPeriod,
        completionByWeek: completion,
        sourceResultTitle: checklistSource.title,
        sourceGeneratedAt: checklistSource.createdAt,
      );
      final completionSummary = buildChecklistCompletionSummary(
        report: parsedChecklist,
        completionByWeek: completion,
      );

      final evaluationContext = ProgressReviewEvaluationEngine.buildContext(
        checklist: parsedChecklist,
        dataSnapshot: dataSnapshot,
        selection: selection,
        monthlyIncomeBdt: config.analysisMonthlyIncomeBdt,
        totalRealExpenses: selection.includes(AnalysisDataSourceId.expenses)
            ? expenses.totalRealExpenses
            : null,
      );

      final prompt = _renderProgressPrompt(
        config,
        dataSnapshot,
        period,
        evaluationContext: evaluationContext,
        checklistPeriod: checklistPeriod,
        checklistSourceTitle: checklistSource.title,
        checklistTargets: checklistTargets,
        checklistCompletionSummary: completionSummary,
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
      final rawOutput = usedApi
          ? await _generateAiOutput(
              aiSettings: aiSettings,
              prompt: prompt,
              systemInstruction: systemInstruction,
            )
          : _generateProgressReview(
              period: period,
              checklistPeriod: checklistPeriod,
              selection: selection,
              monthlySummary: monthlySummary,
              expenses: expenses,
              completionSummary: completionSummary,
              evaluationContext: evaluationContext,
            );
      final apiOutput = ProgressReviewEvaluationEngine.enforce(
        rawOutput,
        evaluationContext,
      );

      final now = DateTime.now();
      final monthLabel = DateFormat('MMMM yyyy').format(period.dataMonthStart);
      final result = AnalysisResult(
        id: '${now.microsecondsSinceEpoch}-${_random.nextInt(9999)}',
        createdAt: now,
        title:
            '${AnalysisKind.progressReview.resultTitlePrefix} · $monthLabel',
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
        analysisKind: AnalysisKind.progressReview,
        checklistSourceId: checklistSource.id,
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

  Future<WeeklyVerificationResult?> verifyWeeklyChecklist({
    required AnalysisSourceSelection selection,
    required AnalysisResult checklistSource,
    required int weekIndex,
  }) async {
    if (state.isRunning || selection.isEmpty) return null;

    final config = await _ref.read(promptConfigProvider.future);
    if (!config.isPersonalInfoComplete) {
      state = state.copyWith(lastError: missingPersonalInfoMessage);
      return null;
    }

    final parsedChecklist = InsightsReportParser.parse(checklistSource.output);
    final weekActions = parsedChecklist.actionsForWeekIndex(weekIndex);
    if (weekActions.isEmpty) {
      state = state.copyWith(
        lastError: 'No checklist actions for this week.',
      );
      return null;
    }

    state = state.copyWith(isRunning: true, clearError: true);

    try {
      final checklistPeriod = checklistSource.analysisPeriod;
      final weekSegment = weekIndex < checklistPeriod.checklistWeeks.length
          ? checklistPeriod.checklistWeeks[weekIndex]
          : null;
      if (weekSegment == null) {
        state = state.copyWith(
          isRunning: false,
          lastError: 'Invalid week index.',
        );
        return null;
      }

      final weekPeriod = AnalysisPeriod.forWeekVerification(
        week: weekSegment,
        checklistMonthStart: checklistPeriod.checklistMonthStart,
      );

      final expensesFull = _ref.read(expensesSummaryProvider);
      final locationFull = _ref.read(locationSummaryProvider);
      final gameActivityFull = _ref.read(gameActivitySummaryProvider);
      final calendar = _ref.read(calendarSummaryProvider);
      final calendarUpcoming = _ref.read(calendarForDisplayProvider);
      final monthlyHealth = await _ref.read(monthlyHealthDataProvider.future);
      final monthlySummary = _sliceHealthForPeriod(
        MonthlyHealthSummary.fromFetch(monthlyHealth),
        weekPeriod,
      );

      final expenses = expensesFull.forAnalysisPeriod(weekPeriod);
      final location = locationFull.forAnalysisPeriod(weekPeriod);
      final gameActivity = gameActivityFull.forAnalysisPeriod(weekPeriod);
      final calendarWeek = calendar.forAnalysisPeriod(weekPeriod);

      final snapshotContext = await loadAnalysisSnapshotContext(
        _ref,
        period: weekPeriod,
        selection: selection,
        config: config,
        calendar: calendarWeek,
      );

      final dataSnapshot = _buildDataSnapshot(
        selection: selection,
        monthlySummary: monthlySummary,
        expenses: expenses,
        location: location,
        gameActivity: gameActivity,
        calendar: calendarWeek,
        calendarUpcomingSource: calendarUpcoming,
        period: weekPeriod,
        workAddress: config.workAddress,
        workHours: config.workHours,
        weekendDays: config.weekendDays,
        context: snapshotContext,
      );

      final completion = await loadChecklistCompletionForResult(
        checklistSource.id,
        parsedChecklist.checklistWeekCount,
      );
      final weekState = completion.stateForWeek(weekIndex);
      final weekHeader = buildWeekHeaderLabel(
        checklistPeriod: checklistPeriod,
        weekIndex: weekIndex,
        report: parsedChecklist,
      );
      final weekTargets = buildWeekChecklistTargetsBlock(
        actions: weekActions,
        state: weekState,
      );

      final evaluationContext = ProgressReviewEvaluationEngine.buildContext(
        checklist: parsedChecklist,
        dataSnapshot: dataSnapshot,
        selection: selection,
        monthlyIncomeBdt: config.analysisMonthlyIncomeBdt,
        totalRealExpenses: selection.includes(AnalysisDataSourceId.expenses)
            ? expenses.totalRealExpenses
            : null,
      );

      final prompt = renderWeeklyVerificationPrompt(
        config: config,
        snapshot: dataSnapshot,
        weekPeriod: weekPeriod,
        checklistPeriod: checklistPeriod,
        checklistSourceTitle: checklistSource.title,
        weekHeader: weekHeader,
        weekChecklistTargets: weekTargets,
        evaluationContext: evaluationContext,
      );

      final systemInstruction = config.composeSystemInstruction();
      final aiSettings = await _ref.read(aiSettingsProvider.future);
      final usedApi = aiSettings.enableApiCalls;
      final rawOutput = usedApi
          ? await _generateAiOutput(
              aiSettings: aiSettings,
              prompt: prompt,
              systemInstruction: systemInstruction,
            )
          : generateLocalWeeklyVerification(
              actions: weekActions,
              weekHeader: weekHeader,
            );

      final parsed = WeeklyChecklistVerificationParser.parse(
        rawOutput,
        actions: weekActions,
      );

      final storageKey = insightChecklistStorageKey(
        checklistSource.id,
        weekIndex,
      );
      await _ref
          .read(insightChecklistProvider(storageKey).notifier)
          .applyVerification(
            completed: parsed.completedIndices,
            failed: parsed.failedIndices,
          );

      final result = WeeklyVerificationResult(
        completedCount: parsed.completedIndices.length,
        failedCount: parsed.failedIndices.length,
        unverifiedCount: parsed.unverifiedIndices.length,
        rawOutput: rawOutput,
      );

      state = state.copyWith(
        isRunning: false,
        clearError: true,
        lastRunAt: DateTime.now(),
      );
      return result;
    } catch (error) {
      state = state.copyWith(isRunning: false, lastError: error.toString());
      return null;
    }
  }
}

const _excludedFromRunMessage = 'Excluded from this analysis run.';

MonthlyHealthSummary _sliceHealthForPeriod(
  MonthlyHealthSummary summary,
  AnalysisPeriod period,
) {
  final start = DateTime(
    period.dataMonthStart.year,
    period.dataMonthStart.month,
    period.dataMonthStart.day,
  );
  final end = DateTime(
    period.dataMonthEnd.year,
    period.dataMonthEnd.month,
    period.dataMonthEnd.day,
  );

  final filtered = summary.dailySleep.where((entry) {
    final day = DateTime(
      entry.wakeDate.year,
      entry.wakeDate.month,
      entry.wakeDate.day,
    );
    return !day.isBefore(start) && !day.isAfter(end);
  }).toList();

  return MonthlyHealthSummary(
    periodStart: period.dataMonthStart,
    periodEnd: period.dataMonthEnd,
    dailySleep: filtered,
    dayCount: period.daysInDataMonth,
  );
}

class AnalysisSnapshotContext {
  const AnalysisSnapshotContext({
    this.previousHealth,
    this.previousExpenses,
    this.previousLocation,
    this.previousGameActivity,
    this.monthlyIncomeBdt = '',
    this.monthlyBudgetBdt = '',
    this.financialInstruction = '',
  });

  final MonthlyHealthSummary? previousHealth;
  final ExpensesSummary? previousExpenses;
  final LocationSummary? previousLocation;
  final GameActivitySummary? previousGameActivity;
  final String monthlyIncomeBdt;
  final String monthlyBudgetBdt;
  final String financialInstruction;
}

Future<AnalysisSnapshotContext> loadAnalysisSnapshotContext(
  Ref ref, {
  required AnalysisPeriod period,
  required AnalysisSourceSelection selection,
  required PromptConfig config,
  required CalendarSummary calendar,
}) async {
  final previousPeriod = period.previousComparablePeriod;
  final previousExpenses = selection.includes(AnalysisDataSourceId.expenses)
      ? ref.read(expensesSummaryProvider).previousCalendarMonthSummary(period)
      : null;
  final previousLocation = selection.includes(AnalysisDataSourceId.location)
      ? ref.read(locationSummaryProvider).forAnalysisPeriod(previousPeriod)
      : null;
  final previousGameActivity =
      selection.includes(AnalysisDataSourceId.gameActivity)
      ? ref
          .read(gameActivitySummaryProvider)
          .forAnalysisPeriod(previousPeriod)
      : null;

  MonthlyHealthSummary? previousHealth;
  if (selection.includes(AnalysisDataSourceId.health)) {
    try {
      final isAuthorized = await ref.read(healthAuthorizationProvider.future);
      if (isAuthorized) {
        final healthService = ref.read(healthServiceProvider);
        final previousFetch = await healthService.fetchMonthlyHealthData(
          previousPeriod,
        );
        if (previousFetch.hasData) {
          previousHealth = MonthlyHealthSummary.fromFetch(previousFetch);
        }
      }
    } catch (_) {}
  }

  return AnalysisSnapshotContext(
    previousHealth: previousHealth,
    previousExpenses: previousExpenses,
    previousLocation: previousLocation,
    previousGameActivity: previousGameActivity,
    monthlyIncomeBdt: config.analysisMonthlyIncomeBdt,
    monthlyBudgetBdt: config.monthlyBudgetBdt,
    financialInstruction: config.financialInstruction,
  );
}

/// Everything sent to the model for a monthly insights run (all sources).
class MonthlyAnalysisPromptPreview {
  const MonthlyAnalysisPromptPreview({
    required this.systemInstruction,
    required this.instructions,
    required this.dataToAnalyze,
    required this.userPrompt,
  });

  final String systemInstruction;
  final String instructions;
  final String dataToAnalyze;
  final String userPrompt;

  /// Full payload as sent to the API (system + user prompt).
  String get fullText =>
      '--- System instruction ---\n\n$systemInstruction\n\n'
      '--- User prompt ---\n\n$userPrompt';
}

Future<MonthlyAnalysisPromptPreview> buildMonthlyAnalysisPromptPreview(
  Ref ref,
) async {
  final selection = AnalysisSourceSelection.all();
  final config = await ref.read(promptConfigProvider.future);
  final period = ref.read(analysisPeriodProvider);
  final expenses = ref.read(expensesForAnalysisProvider);
  final location = ref.read(locationForAnalysisProvider);
  final gameActivity = ref.read(gameActivityForAnalysisProvider);
  final calendar = ref.read(calendarForAnalysisProvider);
  final calendarUpcoming = ref.read(calendarForDisplayProvider);
  final monthlyHealth = await ref.read(monthlyHealthDataProvider.future);
  final monthlySummary = MonthlyHealthSummary.fromFetch(monthlyHealth);

  final snapshotContext = await loadAnalysisSnapshotContext(
    ref,
    period: period,
    selection: selection,
    config: config,
    calendar: calendar,
  );

  final dataSnapshot = _buildDataSnapshot(
    selection: selection,
    monthlySummary: monthlySummary,
    expenses: expenses,
    location: location,
    gameActivity: gameActivity,
    calendar: calendar,
    calendarUpcomingSource: calendarUpcoming,
    period: period,
    workAddress: config.workAddress,
    workHours: config.workHours,
    weekendDays: config.weekendDays,
    context: snapshotContext,
  );

  return MonthlyAnalysisPromptPreview(
    systemInstruction: config.composeSystemInstruction(),
    instructions: _renderInstructionsPrompt(
      config,
      dataSnapshot,
      period,
      selection: selection,
      totalRealExpenses: expenses.totalRealExpenses,
      expensesCurrency: expenses.currency,
    ),
    dataToAnalyze: _buildDataToAnalyzeBlock(
      snapshot: dataSnapshot,
      period: period,
    ),
    userPrompt: _renderPrompt(
      config,
      dataSnapshot,
      period,
      selection: selection,
      totalRealExpenses: expenses.totalRealExpenses,
      expensesCurrency: expenses.currency,
    ),
  );
}

String _buildDataToAnalyzeBlock({
  required Map<String, String> snapshot,
  required AnalysisPeriod period,
}) {
  final template = [
    PromptTemplateSections.derivedMetrics,
    PromptTemplateSections.dataToAnalyze,
  ].join('\n\n');

  return template
      .replaceAll(
        '{{derivedMetrics}}',
        snapshot['derivedMetrics'] ?? 'No derived metrics available.',
      )
      .replaceAll('{{analysisMonth}}', period.dataRangeLabel)
      .replaceAll('{{health}}', snapshot['health'] ?? 'No health data')
      .replaceAll('{{expenses}}', snapshot['expenses'] ?? 'No expense data')
      .replaceAll('{{location}}', snapshot['location'] ?? 'No location data')
      .replaceAll(
        '{{gameActivity}}',
        snapshot['gameActivity'] ?? 'No game activity data',
      )
      .replaceAll('{{calendar}}', snapshot['calendar'] ?? 'No calendar data')
      .replaceAll(
        '{{goalTracking}}',
        snapshot['goalTracking'] ?? '',
      )
      .replaceAll('{{checklistMonth}}', period.checklistMonthLabel)
      .replaceAll(
        '{{checklistWeekBlocks}}',
        period.checklistWeekBlocksPromptBlock,
      );
}

String _renderInstructionsPrompt(
  PromptConfig config,
  Map<String, String> snapshot,
  AnalysisPeriod period, {
  required AnalysisSourceSelection selection,
  required double totalRealExpenses,
  required String expensesCurrency,
}) {
  final focus = config.focus.replaceAll(
    '{{checklistMonth}}',
    period.checklistMonthLabel,
  );
  final template = [
    PromptTemplateSections.internalAnalysisPipeline,
    config.composeRulesForAnalysis(),
    PromptTemplateSections.focusHeader,
    '{{focus}}',
    PromptTemplateSections.outputFormat,
  ].join('\n\n');

  return _applyPromptPlaceholders(
    template,
    snapshot: snapshot,
    period: period,
    selection: selection,
    focus: focus,
    totalExpensesLabel:
        '${totalRealExpenses.toStringAsFixed(2)} $expensesCurrency',
  );
}

Map<String, String> _buildDataSnapshot({
  required AnalysisSourceSelection selection,
  required MonthlyHealthSummary monthlySummary,
  required ExpensesSummary expenses,
  required LocationSummary location,
  required GameActivitySummary gameActivity,
  required CalendarSummary calendar,
  CalendarSummary? calendarUpcomingSource,
  required AnalysisPeriod period,
  String workAddress = '',
  String workHours = '',
  List<int> weekendDays = const [],
  AnalysisSnapshotContext context = const AnalysisSnapshotContext(),
}) {
  final previousWorkStats = selection.includes(AnalysisDataSourceId.location) &&
          context.previousLocation != null
      ? WorkArrivalStats.analyze(
          placeVisits: context.previousLocation!.placeVisitsInRange(
            period.previousComparablePeriod.dataMonthStart,
            period.previousComparablePeriod.dataMonthEnd,
          ),
          workAddress: workAddress,
          workHours: workHours,
        )
      : null;

  final goalTracking = buildGoalTrackingText(
    GoalTrackingInput(
      currentLocation: selection.includes(AnalysisDataSourceId.location)
          ? location
          : null,
      previousLocation: context.previousLocation,
      currentGameActivity: selection.includes(AnalysisDataSourceId.gameActivity)
          ? gameActivity
          : null,
      previousGameActivity: context.previousGameActivity,
    ),
  );

  return {
    'derivedMetrics': buildDerivedMetrics(
      selection: selection,
      health: monthlySummary,
      expenses: expenses,
      location: location,
      calendar: calendar,
      period: period,
      workAddress: workAddress,
      workHours: workHours,
      monthlyIncomeBdt: context.monthlyIncomeBdt,
      monthlyBudgetBdt: context.monthlyBudgetBdt,
      previousWorkStats: previousWorkStats,
    ),
    'health': selection.includes(AnalysisDataSourceId.health)
        ? selection.promptOverrides[AnalysisDataSourceId.health] ??
            _healthText(
              monthlySummary,
              previousNights: context.previousHealth?.dailySleep,
            )
        : _excludedFromRunMessage,
    'expenses': selection.includes(AnalysisDataSourceId.expenses)
        ? selection.promptOverrides[AnalysisDataSourceId.expenses] ??
            _expensesText(
              expenses,
              context: context,
              period: period,
            )
        : _excludedFromRunMessage,
    'expenseCategories': selection.includes(AnalysisDataSourceId.expenses)
        ? expenses.toFinancialContextCategoriesBlock()
        : '* (expenses excluded from this run)',
    'location': selection.includes(AnalysisDataSourceId.location)
        ? selection.promptOverrides[AnalysisDataSourceId.location] ??
            _locationText(
              location,
              period,
              expenses: expenses,
              workAddress: workAddress,
              workHours: workHours,
              weekendDays: weekendDays,
              previousWorkStats: previousWorkStats,
              dailySleep: selection.includes(AnalysisDataSourceId.health)
                  ? monthlySummary.dailySleep
                  : const [],
            )
        : _excludedFromRunMessage,
    'gameActivity': selection.includes(AnalysisDataSourceId.gameActivity)
        ? selection.promptOverrides[AnalysisDataSourceId.gameActivity] ??
            _gameActivityText(
              gameActivity,
              previous: context.previousGameActivity,
            )
        : _excludedFromRunMessage,
    'calendar': selection.includes(AnalysisDataSourceId.calendar)
        ? selection.promptOverrides[AnalysisDataSourceId.calendar] ??
            _calendarText(
              calendar,
              period,
              health: monthlySummary,
              upcomingSource: calendarUpcomingSource,
              location: selection.includes(AnalysisDataSourceId.location)
                  ? location
                  : null,
              expenses: selection.includes(AnalysisDataSourceId.expenses)
                  ? expenses
                  : null,
            )
        : _excludedFromRunMessage,
    'goalTracking': goalTracking.isEmpty
        ? 'No goal metrics available for the selected data sources.'
        : goalTracking,
  };
}

String _renderProgressPrompt(
  PromptConfig config,
  Map<String, String> snapshot,
  AnalysisPeriod period, {
  required ProgressReviewEvaluationContext evaluationContext,
  required AnalysisPeriod checklistPeriod,
  required String checklistSourceTitle,
  required String checklistTargets,
  required String checklistCompletionSummary,
  required double totalRealExpenses,
  required String expensesCurrency,
}) {
  final totalExpensesLabel =
      '${totalRealExpenses.toStringAsFixed(2)} $expensesCurrency';
  final verifiedFinancialFacts =
      evaluationContext.verifiedFinancialRatios?.toPromptBlock() ??
          'Not applicable (expenses excluded or baseline unavailable).';
  final domainScoringRules =
      ProgressReviewEvaluationEngine.buildDomainScoringRulesBlock(
        evaluationContext,
      );
  final dynamicDomainOutputFormat =
      ProgressReviewEvaluationEngine.buildDynamicOutputFormatBlock(
        evaluationContext,
      );

  return config
      .composeProgressTemplate()
      .replaceAll('{{analysisMonth}}', period.dataRangeLabel)
      .replaceAll('{{checklistMonth}}', checklistPeriod.checklistMonthLabel)
      .replaceAll('{{checklistSource}}', checklistSourceTitle)
      .replaceAll('{{checklistTargets}}', checklistTargets)
      .replaceAll(
        '{{checklistCompletionSummary}}',
        checklistCompletionSummary,
      )
      .replaceAll('{{verifiedFinancialFacts}}', verifiedFinancialFacts)
      .replaceAll('{{domainScoringRules}}', domainScoringRules)
      .replaceAll('{{dynamicDomainOutputFormat}}', dynamicDomainOutputFormat)
      .replaceAll('{{totalRealExpenses}}', totalExpensesLabel)
      .replaceAll(
        '{{derivedMetrics}}',
        snapshot['derivedMetrics'] ?? 'No derived metrics available.',
      )
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

String _renderPrompt(
  PromptConfig config,
  Map<String, String> snapshot,
  AnalysisPeriod period, {
  required AnalysisSourceSelection selection,
  required double totalRealExpenses,
  required String expensesCurrency,
}) {
  final totalExpensesLabel =
      '${totalRealExpenses.toStringAsFixed(2)} $expensesCurrency';

  final focus = config.focus.replaceAll(
    '{{checklistMonth}}',
    period.checklistMonthLabel,
  );

  return _applyPromptPlaceholders(
    config.composeTemplate(),
    snapshot: snapshot,
    period: period,
    selection: selection,
    focus: focus,
    totalExpensesLabel: totalExpensesLabel,
  );
}

String _applyPromptPlaceholders(
  String template, {
  required Map<String, String> snapshot,
  required AnalysisPeriod period,
  required AnalysisSourceSelection selection,
  required String focus,
  required String totalExpensesLabel,
}) {
  var rendered = template
      .replaceAll('{{focus}}', focus)
      .replaceAll('{{analysisMonth}}', period.dataRangeLabel)
      .replaceAll('{{checklistMonth}}', period.checklistMonthLabel)
      .replaceAll('{{checklistWeekCount}}', period.checklistWeekCount.toString())
      .replaceAll('{{checklistWeekSegments}}', period.checklistWeeksPromptBlock)
      .replaceAll('{{checklistWeekBlocks}}', period.checklistWeekBlocksPromptBlock)
      .replaceAll(
        '{{checklistDomainEligibility}}',
        buildAnalysisChecklistDomainEligibilityBlock(selection),
      )
      .replaceAll(
        '{{dynamicChecklistDomainSections}}',
        buildAnalysisChecklistDomainSectionsBlock(selection),
      )
      .replaceAll('{{totalRealExpenses}}', totalExpensesLabel)
      .replaceAll(
        '{{derivedMetrics}}',
        snapshot['derivedMetrics'] ?? 'No derived metrics available.',
      )
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

  const legacyWeekPlaceholder = '{{weekRanges}}';
  if (rendered.contains(legacyWeekPlaceholder)) {
    rendered = rendered.replaceFirst(
      legacyWeekPlaceholder,
      period.checklistWeekBlocksPromptBlock,
    );
    rendered = rendered.replaceFirst(
      legacyWeekPlaceholder,
      period.checklistWeeksPromptBlock,
    );
    rendered = rendered.replaceAll(
      legacyWeekPlaceholder,
      period.checklistWeekBlocksPromptBlock,
    );
  }

  return rendered;
}

String _healthText(
  MonthlyHealthSummary summary, {
  List<DailySleepEntry>? previousNights,
}) =>
    summary.toAnalysisPromptText(previousNights: previousNights);

String _expensesText(
  ExpensesSummary summary, {
  required AnalysisSnapshotContext context,
  required AnalysisPeriod period,
}) =>
    summary.toAnalysisPromptText(
      context: ExpensePromptContext(
        previousExpenses: context.previousExpenses,
        monthlyIncomeBdt: context.monthlyIncomeBdt,
        monthlyBudgetBdt: context.monthlyBudgetBdt,
        financialInstruction: context.financialInstruction,
        period: period,
      ),
    );

String _locationText(
  LocationSummary summary,
  AnalysisPeriod period, {
  ExpensesSummary? expenses,
  String workAddress = '',
  String workHours = '',
  List<int> weekendDays = const [],
  WorkArrivalStats? previousWorkStats,
  List<DailySleepEntry> dailySleep = const [],
}) =>
    summary.toAnalysisPromptText(
      dataMonthStart: period.dataMonthStart,
      dataMonthEnd: period.dataMonthEnd,
      workAddress: workAddress,
      workHours: workHours,
      weekendDays: weekendDays,
      fuel: expenses == null
          ? null
          : mobilityFuelSummaryFromExpenses(expenses),
      previousWorkStats: previousWorkStats,
      dailySleep: dailySleep,
    );

String _gameActivityText(
  GameActivitySummary summary, {
  GameActivitySummary? previous,
}) =>
    summary.toAnalysisPromptText(previous: previous);

String _calendarText(
  CalendarSummary summary,
  AnalysisPeriod period, {
  MonthlyHealthSummary? health,
  CalendarSummary? upcomingSource,
  LocationSummary? location,
  ExpensesSummary? expenses,
}) =>
    summary.toAnalysisPromptText(
      health: health,
      upcomingSource: upcomingSource,
      upcomingAfter: period.dataMonthEnd,
      location: location,
      expenses: expenses,
      includeFutureEvents: true,
      includeEventAnalysis: true,
      includeSleepClusterCorrelation: true,
    );

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
    'Checklist month: ${period.checklistMonthLabel}',
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
      '- Game activity data is not loaded for ${period.dataRangeLabel}; import a GameActivity_Export* file.',
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

  lines
    ..add('')
    ..add('### **Clear Next Actions (${period.checklistMonthLabel})**')
    ..add('')
    ..add(period.checklistWeeksPromptBlock)
    ..add('')
    ..add(
      '- Set one health target, one spending cap, and one schedule habit for ${period.checklistMonthLabel}.',
    )
    ..add(
      '- Re-run analysis after the month ends to refresh patterns and the next checklist.',
    );

  return lines.join('\n');
}

String _generateProgressReview({
  required AnalysisPeriod period,
  required AnalysisPeriod checklistPeriod,
  required AnalysisSourceSelection selection,
  required MonthlyHealthSummary monthlySummary,
  required ExpensesSummary expenses,
  required String completionSummary,
  required ProgressReviewEvaluationContext evaluationContext,
}) {
  final lines = <String>[
    '### **Overall Improvement**',
    '',
    '* **Checklist adherence:** $completionSummary',
    '* **Data-backed summary:** Local summary for ${period.dataRangeLabel} '
        'against ${checklistPeriod.checklistMonthLabel} checklist targets.',
    '* **Overall score:** 50 (enable Cloud AI for a scored review)',
    '',
    '### **Domain Progress**',
  ];

  for (final domain in evaluationContext.domainEligibility) {
    lines
      ..add('')
      ..add('#### **${domain.displayName}**')
      ..add('');

    if (!domain.isScorable) {
      lines.add(kProgressReviewDomainExcludedBullet);
      continue;
    }

    switch (domain.id) {
      case ProgressReviewDomainId.health:
        if (!selection.includes(AnalysisDataSourceId.health)) break;
        final nights = monthlySummary.sleepNightsTracked;
        lines
          ..add('* **Checklist target:** See checklist targets in prompt.')
          ..add(
            '* **Actual outcome:** $nights sleep nights tracked over '
            '${monthlySummary.periodRangeLabel}.',
          )
          ..add('* **Verdict:** Partial')
          ..add('* **Score:** 50')
          ..add('* **Delta:** Compare to checklist sleep targets manually.');
      case ProgressReviewDomainId.expenses:
        if (!selection.includes(AnalysisDataSourceId.expenses) ||
            expenses.transactions.isEmpty) {
          break;
        }
        final ratios = evaluationContext.verifiedFinancialRatios;
        lines
          ..add('* **Checklist target:** See checklist spending caps in prompt.')
          ..add(
            '* **Actual outcome:** ${formatBdt(expenses.totalRealExpenses)} '
            '${expenses.currency} real spend '
            '(${expenses.periodRangeLabel ?? period.dataRangeLabel}).',
          )
          ..add('* **Verdict:** Partial')
          ..add('* **Score:** 50')
          ..add(
            '* **Delta:** ${ratios?.buildExpenseDeltaLine() ?? 'Compare to checklist caps manually.'}',
          );
      case ProgressReviewDomainId.location:
      case ProgressReviewDomainId.gaming:
      case ProgressReviewDomainId.calendar:
        lines
          ..add('* **Checklist target:** See checklist targets in prompt.')
          ..add('* **Actual outcome:** See current-month data in prompt.')
          ..add('* **Verdict:** Partial')
          ..add('* **Score:** 50')
          ..add('* **Delta:** Enable Cloud AI for verified deltas.');
    }
  }

  lines
    ..add('')
    ..add('### **What Worked**')
    ..add('')
    ..add('* **Tracked adherence:** $completionSummary')
    ..add('')
    ..add('### **Gaps & Next Focus**')
    ..add('')
    ..add(
      '* **Enable Cloud AI:** Turn on API calls in General settings for '
      'numeric domain scores and deltas.',
    );

  return lines.join('\n');
}
