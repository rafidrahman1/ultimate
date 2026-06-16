import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/progress_review/progress_review_evaluation.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/results/insight_checklist_service.dart';
import 'package:personal/features/results/insights_models.dart';

/// Result of a weekly checklist verification run.
class WeeklyVerificationResult {
  const WeeklyVerificationResult({
    required this.completedCount,
    required this.failedCount,
    required this.unverifiedCount,
    required this.rawOutput,
  });

  final int completedCount;
  final int failedCount;
  final int unverifiedCount;
  final String rawOutput;
}

/// Builds the single-week checklist block for verification prompts.
String buildWeekChecklistTargetsBlock({
  required List<ActionDirective> actions,
  required WeekChecklistState state,
}) {
  final buffer = StringBuffer();
  for (var actionIndex = 0; actionIndex < actions.length; actionIndex++) {
    final action = actions[actionIndex];
    final mark = switch (state.statusFor(actionIndex)) {
      ChecklistItemStatus.completed => '[x]',
      ChecklistItemStatus.failed => '[!]',
      ChecklistItemStatus.pending => '[ ]',
    };
    final group = action.groupLabel == null ? '' : ' (${action.groupLabel})';
    buffer.writeln(
      '${actionIndex + 1}. $mark **${action.title}**$group: ${action.description}'
          .trim(),
    );
  }
  return buffer.toString().trimRight();
}

String buildWeekHeaderLabel({
  required AnalysisPeriod checklistPeriod,
  required int weekIndex,
  required InsightsParsedReport report,
}) {
  final weekLabel = weekIndex < checklistPeriod.checklistWeeks.length
      ? 'Week ${checklistPeriod.checklistWeeks[weekIndex].weekNumber} · '
          '${checklistPeriod.checklistWeeks[weekIndex].isoRangeLabel}'
      : 'Week ${weekIndex + 1}';
  final theme = report.themeForWeekIndex(weekIndex);
  return theme == null ? weekLabel : '$weekLabel · Theme: $theme';
}

String renderWeeklyVerificationPrompt({
  required PromptConfig config,
  required Map<String, String> snapshot,
  required AnalysisPeriod weekPeriod,
  required AnalysisPeriod checklistPeriod,
  required String checklistSourceTitle,
  required String weekHeader,
  required String weekChecklistTargets,
  required ProgressReviewEvaluationContext evaluationContext,
}) {
  final verifiedFinancialFacts =
      evaluationContext.verifiedFinancialRatios?.toPromptBlock() ??
          'Not applicable (expenses excluded or baseline unavailable).';
  final domainScoringRules =
      ProgressReviewEvaluationEngine.buildDomainScoringRulesBlock(
        evaluationContext,
      );

  return config
      .composeWeeklyVerifyTemplate()
      .replaceAll('{{checklistMonth}}', checklistPeriod.checklistMonthLabel)
      .replaceAll('{{checklistSource}}', checklistSourceTitle)
      .replaceAll('{{weekHeader}}', weekHeader)
      .replaceAll('{{weekRangeLabel}}', weekPeriod.dataRangeLabel)
      .replaceAll('{{weekChecklistTargets}}', weekChecklistTargets)
      .replaceAll('{{verifiedFinancialFacts}}', verifiedFinancialFacts)
      .replaceAll('{{domainScoringRules}}', domainScoringRules)
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

String generateLocalWeeklyVerification({
  required List<ActionDirective> actions,
  required String weekHeader,
}) {
  final buffer = StringBuffer()
    ..writeln('### **Weekly Checklist Verification**')
    ..writeln()
    ..writeln('##### $weekHeader')
    ..writeln();

  for (var i = 0; i < actions.length; i++) {
    final action = actions[i];
    buffer.writeln(
      '${i + 1}. **${action.title}** — **Verdict:** Unverified',
    );
    buffer.writeln('   - **Evidence:** Insufficient data (local summary mode)');
    buffer.writeln(
      '   - **Rationale:** Enable Cloud AI for data-backed verification.',
    );
    buffer.writeln();
  }

  return buffer.toString().trimRight();
}
