import 'package:flutter_test/flutter_test.dart';
import 'package:personal/core/period/analysis_period.dart';
import 'package:personal/features/analysis/ui/analysis_data_preview.dart';
import 'package:personal/features/calendar/data/calendar_event.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/data/health_service.dart';
import 'package:personal/features/health/data/health_summary.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/results/local/local_insights_generator.dart';
import 'package:personal/features/results/reports/insights_parser.dart';

/// The offline generator and the parser are written separately but must agree
/// on the report format; otherwise "API calls off" produces a report with no
/// checklist.
void main() {
  test('local insights parse into a checklist with one week per segment', () {
    final period = AnalysisPeriod.forReference(DateTime(2026, 3, 15));
    final start = period.dataMonthStart;
    final end = period.dataMonthEnd;
    final text = generateInsights(
      period: period,
      selection: AnalysisSourceSelection.all(),
      monthlySummary: MonthlyHealthSummary(
        periodStart: start,
        periodEnd: end,
        dailySleep: const [],
        dayCount: period.daysInDataMonth,
      ),
      monthlyHealth: MonthlyHealthFetchResult(
        points: const [],
        periodStart: start,
        periodEnd: end,
        dayCount: period.daysInDataMonth,
      ),
      expenses: const ExpensesSummary(transactions: []),
      location: const LocationSummary(activities: []),
      gameActivity: const GameActivitySummary(sessions: []),
      calendar: const CalendarSummary(events: []),
      focus: 'general',
    );

    final report = InsightsReportParser.parse(text);
    expect(report.actions, isNotEmpty, reason: 'checklist actions parsed');
    expect(report.checklistWeekCount, period.checklistWeekCount);
  });
}
