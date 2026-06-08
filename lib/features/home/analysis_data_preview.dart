import 'package:flutter/material.dart';

import '../../core/analysis_period.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../calendar/calendar_event.dart';
import '../expenses/cashew_transaction.dart';
import '../game_activity/game_activity_session.dart';
import '../health/health_service.dart';
import '../health/health_summary.dart';
import '../location/timeline_activity.dart';

enum AnalysisDataSourceId {
  health,
  expenses,
  location,
  gameActivity,
  calendar,
}

Color _sourceColor(BuildContext context, AnalysisDataSourceId id) {
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
  const AnalysisSourceSelection(this.included);

  final Set<AnalysisDataSourceId> included;

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
    required this.color,
    required this.hasData,
    required this.detail,
    this.note,
  });

  final AnalysisDataSourceId id;
  final String label;
  final IconData icon;
  final Color color;
  final bool hasData;
  final String detail;
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
  required BuildContext context,
  required AnalysisPeriod period,
  required MonthlyHealthFetchResult? healthFetch,
  required bool healthLoading,
  required ExpensesSummary expenses,
  required LocationSummary location,
  required GameActivitySummary gameActivity,
  required CalendarSummary calendar,
  required String insightEngineLabel,
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
      _healthPreview(context, healthSummary, healthLoading),
      _expensesPreview(context, expenses),
      _locationPreview(context, location),
      _gameActivityPreview(context, gameActivity),
      _calendarPreview(context, calendar, period),
    ],
  );
}

AnalysisDataSourcePreview _healthPreview(
  BuildContext context,
  MonthlyHealthSummary? summary,
  bool loading,
) {
  if (loading) {
    return AnalysisDataSourcePreview(
      id: AnalysisDataSourceId.health,
      label: 'Health',
      icon: Icons.health_and_safety_outlined,
      color: _sourceColor(context, AnalysisDataSourceId.health),
      hasData: false,
      detail: 'Loading health data…',
    );
  }

  if (summary == null) {
    return AnalysisDataSourcePreview(
      id: AnalysisDataSourceId.health,
      label: 'Health',
      icon: Icons.health_and_safety_outlined,
      color: _sourceColor(context, AnalysisDataSourceId.health),
      hasData: false,
      detail: 'No health data for this month',
      note: 'Import or refresh from the Health screen',
    );
  }

  return AnalysisDataSourcePreview(
    id: AnalysisDataSourceId.health,
    label: 'Health',
    icon: Icons.health_and_safety_outlined,
    color: _sourceColor(context, AnalysisDataSourceId.health),
    hasData: true,
    detail:
        '${summary.avgStepsPerDay.round()} avg steps/day · '
        '${summary.sleepNightsTracked} sleep nights tracked',
    note: summary.periodRangeLabel,
  );
}

AnalysisDataSourcePreview _expensesPreview(
  BuildContext context,
  ExpensesSummary expenses,
) {
  if (expenses.transactions.isEmpty) {
    return AnalysisDataSourcePreview(
      id: AnalysisDataSourceId.expenses,
      label: 'Expenses',
      icon: Icons.account_balance_wallet_outlined,
      color: _sourceColor(context, AnalysisDataSourceId.expenses),
      hasData: false,
      detail: 'No transactions in analysis month',
      note: 'Import Cashew CSV from Expenses',
    );
  }

  final currency = expenses.currency.isEmpty ? '' : ' ${expenses.currency}';
  return AnalysisDataSourcePreview(
    id: AnalysisDataSourceId.expenses,
    label: 'Expenses',
    icon: Icons.account_balance_wallet_outlined,
    color: _sourceColor(context, AnalysisDataSourceId.expenses),
    hasData: true,
    detail:
        '${expenses.transactions.length} transactions · '
        '${expenses.totalRealExpenses.toStringAsFixed(0)}$currency real spend',
    note: '${expenses.realExpenseCount} expense line items',
  );
}

AnalysisDataSourcePreview _locationPreview(
  BuildContext context,
  LocationSummary location,
) {
  if (location.activities.isEmpty) {
    return AnalysisDataSourcePreview(
      id: AnalysisDataSourceId.location,
      label: 'Location',
      icon: Icons.route_outlined,
      color: _sourceColor(context, AnalysisDataSourceId.location),
      hasData: false,
      detail: 'No location history in analysis month',
      note: 'Import Google Timeline from Location',
    );
  }

  final km = location.periodTotalDistanceMeters / 1000;
  return AnalysisDataSourcePreview(
    id: AnalysisDataSourceId.location,
    label: 'Location',
    icon: Icons.route_outlined,
    color: _sourceColor(context, AnalysisDataSourceId.location),
    hasData: true,
    detail:
        '${location.activities.length} activities · '
        '${km.toStringAsFixed(1)} km total',
  );
}

AnalysisDataSourcePreview _gameActivityPreview(
  BuildContext context,
  GameActivitySummary summary,
) {
  if (summary.sessions.isEmpty) {
    return AnalysisDataSourcePreview(
      id: AnalysisDataSourceId.gameActivity,
      label: 'Game Activity',
      icon: Icons.sports_esports_outlined,
      color: _sourceColor(context, AnalysisDataSourceId.gameActivity),
      hasData: false,
      detail: 'No gaming sessions in analysis month',
      note: 'Import Steam/playtime export from Game Activity',
    );
  }

  return AnalysisDataSourcePreview(
    id: AnalysisDataSourceId.gameActivity,
    label: 'Game Activity',
    icon: Icons.sports_esports_outlined,
    color: _sourceColor(context, AnalysisDataSourceId.gameActivity),
    hasData: true,
    detail:
        '${summary.sessions.length} sessions · '
        '${summary.uniqueGameCount} games · '
        '${_formatPlayTime(summary.totalPlayTime)} play time',
    note: summary.periodRangeLabel,
  );
}

AnalysisDataSourcePreview _calendarPreview(
  BuildContext context,
  CalendarSummary calendar,
  AnalysisPeriod period,
) {
  if (calendar.events.isEmpty) {
    return AnalysisDataSourcePreview(
      id: AnalysisDataSourceId.calendar,
      label: 'Calendar',
      icon: Icons.calendar_month_outlined,
      color: _sourceColor(context, AnalysisDataSourceId.calendar),
      hasData: false,
      detail: 'No calendar events in range',
      note:
          'Sync Google Calendar (${period.dataRangeLabel} through ${period.checklistMonthLabel})',
    );
  }

  return AnalysisDataSourcePreview(
    id: AnalysisDataSourceId.calendar,
    label: 'Calendar',
    icon: Icons.calendar_month_outlined,
    color: _sourceColor(context, AnalysisDataSourceId.calendar),
    hasData: true,
    detail: '${calendar.events.length} events',
    note:
        'Includes ${period.checklistMonthLabel} for weekly checklist planning',
  );
}

String _formatPlayTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}
