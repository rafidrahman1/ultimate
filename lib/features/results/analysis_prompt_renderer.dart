import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/progress_review/progress_review_evaluation.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/prompts/prompt_template_sections.dart';
import 'package:personal/features/results/analysis_checklist_builder.dart';
import 'package:personal/features/results/analysis_snapshot_builder.dart';

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
    userPrompt: renderPrompt(
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
      .replaceAll('{{goalTracking}}', snapshot['goalTracking'] ?? '')
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

String renderProgressPrompt(
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
      .replaceAll('{{checklistCompletionSummary}}', checklistCompletionSummary)
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
      .replaceAll('{{calendar}}', snapshot['calendar'] ?? 'No calendar data');
}

String renderPrompt(
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
      .replaceAll(
        '{{checklistWeekCount}}',
        period.checklistWeekCount.toString(),
      )
      .replaceAll('{{checklistWeekSegments}}', period.checklistWeeksPromptBlock)
      .replaceAll(
        '{{checklistWeekBlocks}}',
        period.checklistWeekBlocksPromptBlock,
      )
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
      .replaceAll('{{calendar}}', snapshot['calendar'] ?? 'No calendar data');

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
