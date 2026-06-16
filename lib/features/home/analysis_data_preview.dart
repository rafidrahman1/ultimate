import 'package:flutter/material.dart';

import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/location/mobility_prompt_builder.dart';
import 'package:personal/features/location/timeline_activity.dart';

enum AnalysisDataSourceId {
  health,
  expenses,
  location,
  gameActivity,
  calendar,
}

Color analysisSourceColor(BuildContext context, AnalysisDataSourceId id) {
  return switch (id) {
    AnalysisDataSourceId.health => AppSemanticColors.health(context),
    AnalysisDataSourceId.expenses => AppSemanticColors.expenses(context),
    AnalysisDataSourceId.location => AppSemanticColors.location(context),
    AnalysisDataSourceId.gameActivity => AppSemanticColors.gameActivity(context),
    AnalysisDataSourceId.calendar => AppSemanticColors.calendar(context),
  };
}

/// Which domains the user chose to include in a single analysis run.
class AnalysisSourceSelection {
  const AnalysisSourceSelection(
    this.included, {
    this.promptOverrides = const {},
  });

  final Set<AnalysisDataSourceId> included;
  final Map<AnalysisDataSourceId, String> promptOverrides;

  factory AnalysisSourceSelection.all() =>
      AnalysisSourceSelection(Set<AnalysisDataSourceId>.from(AnalysisDataSourceId.values));

  bool includes(AnalysisDataSourceId id) => included.contains(id);

  bool get isEmpty => included.isEmpty;
}

/// One row in the pre-run analysis confirmation sheet.
class AnalysisDataSourcePreview {
  const AnalysisDataSourcePreview({
    required this.id,
    required this.label,
    required this.icon,
    required this.hasData,
    required this.detail,
    required this.promptText,
    this.note,
  });

  final AnalysisDataSourceId id;
  final String label;
  final IconData icon;
  final bool hasData;
  final String detail;
  final String promptText;
  final String? note;
}

class AnalysisRunPreview {
  const AnalysisRunPreview({
    required this.period,
    required this.sources,
    required this.insightEngineLabel,
    this.healthLoading = false,
  });

  final AnalysisPeriod period;
  final List<AnalysisDataSourcePreview> sources;
  final String insightEngineLabel;
  final bool healthLoading;

  int get loadedSourceCount => sources.where((s) => s.hasData).length;

  bool get hasAnyData => loadedSourceCount > 0;
}

AnalysisRunPreview buildAnalysisRunPreview({
  required AnalysisPeriod period,
  required MonthlyHealthFetchResult? healthFetch,
  required bool healthLoading,
  required ExpensesSummary expenses,
  required LocationSummary location,
  required GameActivitySummary gameActivity,
  required CalendarSummary calendar,
  CalendarSummary? calendarUpcomingSource,
  required String insightEngineLabel,
  String workAddress = '',
  String workHours = '',
  List<int> weekendDays = const [],
}) {
  MonthlyHealthSummary? healthSummary;
  if (healthFetch != null && healthFetch.hasData) {
    healthSummary = MonthlyHealthSummary.fromFetch(healthFetch);
  }

  return AnalysisRunPreview(
    period: period,
    insightEngineLabel: insightEngineLabel,
    healthLoading: healthLoading,
    sources: [
      _healthPreview(healthSummary, healthLoading),
      _expensesPreview(expenses),
      _locationPreview(
        location,
        period,
        expenses: expenses,
        workAddress: workAddress,
        workHours: workHours,
        weekendDays: weekendDays,
      ),
      _gameActivityPreview(gameActivity),
      _calendarPreview(
        calendar,
        period,
        health: healthSummary,
        upcomingSource: calendarUpcomingSource,
        location: location,
        expenses: expenses,
      ),
    ],
  );
}

AnalysisDataSourcePreview _healthPreview(
  MonthlyHealthSummary? summary,
  bool loading,
) {
  if (loading) {
    return const AnalysisDataSourcePreview(
      id: AnalysisDataSourceId.health,
      label: 'Health',
      icon: Icons.health_and_safety_outlined,
      hasData: false,
      detail: 'Loading health data…',
      promptText: 'No health data for this month.',
    );
  }

  if (summary == null) {
    return const AnalysisDataSourcePreview(
      id: AnalysisDataSourceId.health,
      label: 'Health',
      icon: Icons.health_and_safety_outlined,
      hasData: false,
      detail: 'No health data for this month',
      promptText: 'No health data for this month.',
      note: 'Import or refresh from the Health screen',
    );
  }

  return AnalysisDataSourcePreview(
    id: AnalysisDataSourceId.health,
    label: 'Health',
    icon: Icons.health_and_safety_outlined,
    hasData: true,
    detail: '${summary.sleepNightsTracked} sleep nights tracked',
    promptText: summary.toAnalysisPromptText(),
    note: summary.periodRangeLabel,
  );
}

AnalysisDataSourcePreview _expensesPreview(ExpensesSummary expenses) {
  if (expenses.transactions.isEmpty) {
    return AnalysisDataSourcePreview(
      id: AnalysisDataSourceId.expenses,
      label: 'Expenses',
      icon: Icons.account_balance_wallet_outlined,
      hasData: false,
      detail: 'No transactions in analysis month',
      promptText: expenses.toAnalysisPromptText(),
      note: 'Import Cashew CSV from Expenses',
    );
  }

  final currency = expenses.currency.isEmpty ? '' : ' ${expenses.currency}';
  return AnalysisDataSourcePreview(
    id: AnalysisDataSourceId.expenses,
    label: 'Expenses',
    icon: Icons.account_balance_wallet_outlined,
    hasData: true,
    detail:
        '${expenses.transactions.length} transactions · '
        '${expenses.totalRealExpenses.toStringAsFixed(0)}$currency real spend',
    promptText: expenses.toAnalysisPromptText(),
    note: '${expenses.realExpenseCount} expense line items',
  );
}

AnalysisDataSourcePreview _locationPreview(
  LocationSummary location,
  AnalysisPeriod period, {
  required ExpensesSummary expenses,
  String workAddress = '',
  String workHours = '',
  List<int> weekendDays = const [],
}) {
  final promptText = location.toAnalysisPromptText(
    dataMonthStart: period.dataMonthStart,
    dataMonthEnd: period.dataMonthEnd,
    workAddress: workAddress,
    workHours: workHours,
    weekendDays: weekendDays,
    fuel: mobilityFuelSummaryFromExpenses(expenses),
  );

  if (location.activities.isEmpty) {
    return AnalysisDataSourcePreview(
      id: AnalysisDataSourceId.location,
      label: 'Location',
      icon: Icons.route_outlined,
      hasData: false,
      detail: 'No location history in analysis month',
      promptText: promptText,
      note: 'Import Google Timeline from Location',
    );
  }

  final km = location.periodTotalDistanceMeters / 1000;
  return AnalysisDataSourcePreview(
    id: AnalysisDataSourceId.location,
    label: 'Location',
    icon: Icons.route_outlined,
    hasData: true,
    detail:
        '${location.activities.length} activities · '
        '${km.toStringAsFixed(1)} km total',
    promptText: promptText,
  );
}

AnalysisDataSourcePreview _gameActivityPreview(GameActivitySummary summary) {
  if (summary.sessions.isEmpty) {
    return AnalysisDataSourcePreview(
      id: AnalysisDataSourceId.gameActivity,
      label: 'Game Activity',
      icon: Icons.sports_esports_outlined,
      hasData: false,
      detail: 'No gaming sessions in analysis month',
      promptText: summary.toAnalysisPromptText(),
      note: 'Import GameActivity_Export*.csv',
    );
  }

  return AnalysisDataSourcePreview(
    id: AnalysisDataSourceId.gameActivity,
    label: 'Game Activity',
    icon: Icons.sports_esports_outlined,
    hasData: true,
    detail:
        '${summary.sessions.length} sessions · '
        '${summary.uniqueGameCount} games · '
        '${_formatPlayTime(summary.totalPlayTime)} play time',
    promptText: summary.toAnalysisPromptText(),
    note: summary.periodRangeLabel,
  );
}

AnalysisDataSourcePreview _calendarPreview(
  CalendarSummary calendar,
  AnalysisPeriod period, {
  MonthlyHealthSummary? health,
  CalendarSummary? upcomingSource,
  LocationSummary? location,
  ExpensesSummary? expenses,
}) {
  final promptText = calendar.toAnalysisPromptText(
    health: health,
    upcomingSource: upcomingSource,
    upcomingAfter: period.dataMonthEnd,
    location: location,
    expenses: expenses,
    includeFutureEvents: true,
    includeEventAnalysis: true,
    includeSleepClusterCorrelation: true,
  );

  if (calendar.events.isEmpty) {
    return AnalysisDataSourcePreview(
      id: AnalysisDataSourceId.calendar,
      label: 'Calendar',
      icon: Icons.calendar_month_outlined,
      hasData: false,
      detail: 'No calendar events in range',
      promptText: promptText,
      note:
          'Sync Google Calendar (${period.dataRangeLabel})',
    );
  }

  return AnalysisDataSourcePreview(
    id: AnalysisDataSourceId.calendar,
    label: 'Calendar',
    icon: Icons.calendar_month_outlined,
    hasData: true,
    detail: '${calendar.events.length} events',
    promptText: promptText,
    note:
        period.dataRangeLabel,
  );
}

String _formatPlayTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}
