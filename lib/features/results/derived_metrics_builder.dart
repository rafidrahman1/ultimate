import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/work_arrival_stats.dart';
import 'package:personal/features/results/analytics_pipeline_validation.dart';
import 'package:personal/features/results/anomaly_ranking.dart';
import 'package:personal/features/results/derived_metric_validation.dart';
import 'package:personal/features/results/stable_month_detection.dart';

String buildDerivedMetrics({
  required AnalysisSourceSelection selection,
  required MonthlyHealthSummary health,
  required ExpensesSummary expenses,
  required LocationSummary location,
  required CalendarSummary calendar,
  required AnalysisPeriod period,
  String workAddress = '',
  String workHours = '',
  String monthlyIncomeBdt = '',
  String monthlyBudgetBdt = '',
  WorkArrivalStats? previousWorkStats,
}) {
  final workStats = selection.includes(AnalysisDataSourceId.location)
      ? WorkArrivalStats.analyze(
          placeVisits: location.placeVisitsInRange(
            period.dataMonthStart,
            period.dataMonthEnd,
          ),
          workAddress: workAddress,
          workHours: workHours,
        )
      : null;
  final calendarEvents = selection.includes(AnalysisDataSourceId.calendar)
      ? listMajorCalendarEvents(calendar)
      : const <MajorCalendarEvent>[];
  final expenseAssociationEvents =
      selection.includes(AnalysisDataSourceId.calendar)
      ? listExpenseAssociationCalendarEvents(calendar)
      : const <MajorCalendarEvent>[];
  final resolvedBudget = resolveMonthlyBudgetBdt(
    monthlyBudgetBdt: monthlyBudgetBdt,
  );

  final stableMonth = evaluateStableMonth(
    selection: selection,
    dailySleep: health.dailySleep,
    expenses: selection.includes(AnalysisDataSourceId.expenses)
        ? expenses
        : null,
    calendarEvents: calendarEvents,
    workStats: workStats,
  );
  final sections = <String>[
    buildHealthyMonthDetectionText(stableMonth),
  ];

  final ranking = buildAnomalyCandidates(
    dailySleep: selection.includes(AnalysisDataSourceId.health)
        ? health.dailySleep
        : const [],
    expenses: selection.includes(AnalysisDataSourceId.expenses)
        ? expenses
        : null,
    calendarEvents: expenseAssociationEvents,
    workStats: workStats,
    previousWorkStats: previousWorkStats,
    monthlyBudgetBdt: resolvedBudget,
    monthlyIncomeBdt: monthlyIncomeBdt,
  );
  final rankingText = formatAnomalyCandidatesText(ranking);
  sections.add(rankingText);

  if (sections.isEmpty) {
    return 'No derived metrics available for the selected data sources.';
  }

  return DerivedMetricValidation.sanitizeDerivedMetricsOutput(
    sections.join('\n\n'),
  );
}
