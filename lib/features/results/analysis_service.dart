import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/error_display.dart';
import 'package:personal/features/analysis/analysis_kind.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/analysis_result_period.dart';
import 'package:personal/features/analysis/analysis_reports_storage.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/features/game_activity/game_activity_service.dart';
import 'package:personal/features/location/location_service.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/progress_review/progress_review_evaluation.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/core/app_lifecycle_service.dart';
import 'package:personal/features/results/ai_client.dart';
import 'package:personal/features/results/analysis_prompt_renderer.dart';
import 'package:personal/features/results/analysis_snapshot_builder.dart';
import 'package:personal/features/results/checklist_prompt_builder.dart';
import 'package:personal/features/results/insight_checklist_service.dart';
import 'package:personal/features/results/insights_parser.dart';
import 'package:personal/features/results/local_insights_generator.dart';
import 'package:personal/features/results/local_progress_review_generator.dart';
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

      final dataSnapshot = buildDataSnapshot(
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

      final prompt = renderPrompt(
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
          : generateInsights(
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
          generate:
              ({
                required settings,
                required prompt,
                required systemInstruction,
              }) => _generateAiOutput(
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
        title:
            '${AnalysisKind.monthlyInsights.resultTitlePrefix} · $monthLabel',
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
      state = state.copyWith(isRunning: false, lastError: humanizeError(error));
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

      final dataSnapshot = buildDataSnapshot(
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

      final prompt = renderProgressPrompt(
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
          : generateProgressReview(
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
        title: '${AnalysisKind.progressReview.resultTitlePrefix} · $monthLabel',
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
      state = state.copyWith(isRunning: false, lastError: humanizeError(error));
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
      state = state.copyWith(lastError: 'No checklist actions for this week.');
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

      final dataSnapshot = buildDataSnapshot(
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
      state = state.copyWith(isRunning: false, lastError: humanizeError(error));
      return null;
    }
  }
}

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
