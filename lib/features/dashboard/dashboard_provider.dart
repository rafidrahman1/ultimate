import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/analysis/period_comparison.dart';
import 'package:personal/features/dashboard/dashboard_view_data.dart';
import 'package:personal/features/game_activity/game_activity_service.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/location/location_service.dart';
import 'package:personal/features/location/work_schedule_settings_service.dart';

final dashboardViewProvider = FutureProvider<DashboardViewData>((ref) async {
  final period = ref.watch(analysisPeriodProvider);
  final healthFetch = await ref.read(monthlyHealthDataProvider.future);
  final expenses = ref.watch(expensesForAnalysisProvider);
  final location = ref.watch(locationForAnalysisProvider);
  final gameActivity = ref.watch(gameActivityForAnalysisProvider);
  final calendar = ref.watch(calendarForAnalysisProvider);
  final workSchedule = await ref.watch(workScheduleSettingsProvider.future);

  final previousPeriod = period.previousComparablePeriod;
  final previousLocation = ref
      .watch(locationSummaryProvider)
      .forAnalysisPeriod(previousPeriod);
  final previousGameActivity = ref
      .watch(gameActivitySummaryProvider)
      .forAnalysisPeriod(previousPeriod);

  final healthSummary = healthFetch.hasData
      ? MonthlyHealthSummary.fromFetch(healthFetch)
      : null;

  return buildDashboardViewData(
    period: period,
    healthSummary: healthSummary,
    expenses: expenses,
    location: location,
    gameActivity: gameActivity,
    calendar: calendar,
    workSchedule: workSchedule,
    previousLocation: previousLocation,
    previousGameActivity: previousGameActivity,
  );
});
