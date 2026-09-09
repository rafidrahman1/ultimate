import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/app_log.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/period_comparison.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/features/game_activity/game_activity_service.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/location/location_service.dart';
import 'package:personal/features/location/mobility_prompt_builder.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/work_arrival_stats.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/results/derived_metrics_builder.dart';
import 'package:personal/features/results/goal_tracking_builder.dart';

const _excludedFromRunMessage = 'Excluded from this analysis run.';

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
      ? ref.read(gameActivitySummaryProvider).forAnalysisPeriod(previousPeriod)
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
    } catch (error) {
      AppLog.warn(
        'Failed to load previous-period health data for snapshot context: $error',
      );
    }
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

Map<String, String> buildDataSnapshot({
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
  final previousWorkStats =
      selection.includes(AnalysisDataSourceId.location) &&
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
              _expensesText(expenses, context: context, period: period)
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

String _healthText(
  MonthlyHealthSummary summary, {
  List<DailySleepEntry>? previousNights,
}) => summary.toAnalysisPromptText(previousNights: previousNights);

String _expensesText(
  ExpensesSummary summary, {
  required AnalysisSnapshotContext context,
  required AnalysisPeriod period,
}) => summary.toAnalysisPromptText(
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
}) => summary.toAnalysisPromptText(
  dataMonthStart: period.dataMonthStart,
  dataMonthEnd: period.dataMonthEnd,
  workAddress: workAddress,
  workHours: workHours,
  weekendDays: weekendDays,
  fuel: expenses == null ? null : mobilityFuelSummaryFromExpenses(expenses),
  previousWorkStats: previousWorkStats,
  dailySleep: dailySleep,
);

String _gameActivityText(
  GameActivitySummary summary, {
  GameActivitySummary? previous,
}) => summary.toAnalysisPromptText(previous: previous);

String _calendarText(
  CalendarSummary summary,
  AnalysisPeriod period, {
  MonthlyHealthSummary? health,
  CalendarSummary? upcomingSource,
  LocationSummary? location,
  ExpensesSummary? expenses,
}) => summary.toAnalysisPromptText(
  health: health,
  upcomingSource: upcomingSource,
  upcomingAfter: period.dataMonthEnd,
  location: location,
  expenses: expenses,
  includeFutureEvents: true,
  includeEventAnalysis: true,
  includeSleepClusterCorrelation: true,
);
