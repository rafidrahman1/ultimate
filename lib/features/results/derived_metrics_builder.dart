import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_metrics.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/location/mobility_prompt_builder.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/work_arrival_stats.dart';
import 'package:personal/features/results/anomaly_ranking.dart';
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

  if (selection.includes(AnalysisDataSourceId.health) &&
      health.sleepNightsTracked > 0) {
    final sleepDebt = buildSleepDebtText(health.dailySleep);
    if (sleepDebt.isNotEmpty) {
      sections.add('Sleep:\n$sleepDebt');
    }
  }

  if (selection.includes(AnalysisDataSourceId.expenses) &&
      expenses.expensesByCategory.isNotEmpty) {
    final profiles = buildExpenseCategoryProfilesText(
      expenses,
      calendarEvents: calendarEvents,
    );
    if (profiles.isNotEmpty) {
      sections.add('Expenses:\n$profiles');
    }
  }

  if (selection.includes(AnalysisDataSourceId.location) && location.hasAnyData) {
    if (workStats != null &&
        workStats.lateArrivals.isNotEmpty &&
        selection.includes(AnalysisDataSourceId.health)) {
      final correlation = buildLateArrivalCorrelationText(
        workStats: workStats,
        dailySleep: health.dailySleep,
      );
      if (correlation.isNotEmpty) {
        sections.add('Mobility:\n$correlation');
      }
    }
  }

  if (selection.includes(AnalysisDataSourceId.calendar) &&
      calendar.events.isNotEmpty &&
      selection.includes(AnalysisDataSourceId.health)) {
    final impact = buildCalendarImpactDerivedText(
      calendar,
      health: health,
      expenses: selection.includes(AnalysisDataSourceId.expenses)
          ? expenses
          : null,
    );
    if (impact.isNotEmpty) {
      sections.add('Calendar Impact:\n$impact');
    }
  }

  final ranking = buildAnomalyCandidates(
    dailySleep: selection.includes(AnalysisDataSourceId.health)
        ? health.dailySleep
        : const [],
    expenses: selection.includes(AnalysisDataSourceId.expenses)
        ? expenses
        : null,
    calendarEvents: calendarEvents,
    workStats: workStats,
  );
  final rankingText = formatAnomalyCandidatesText(ranking);
  if (rankingText.isNotEmpty) {
    sections.add(rankingText);
  }

  if (sections.isEmpty) {
    return 'No derived metrics available for the selected data sources.';
  }

  return sections.join('\n\n');
}
