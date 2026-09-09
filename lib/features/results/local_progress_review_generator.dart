import 'package:personal/core/formatting.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/progress_review/progress_review_evaluation.dart';

String generateProgressReview({
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
          ..add(
            '* **Checklist target:** See checklist spending caps in prompt.',
          )
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
