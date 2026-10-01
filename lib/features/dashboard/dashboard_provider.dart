import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/dashboard/dashboard_view_data.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/results/analysis_snapshot_builder.dart';

final dashboardViewProvider = FutureProvider<DashboardViewData>((ref) async {
  final period = ref.watch(analysisPeriodProvider);
  final selection = AnalysisSourceSelection.all();
  // Watch everything before the first await so all dependencies register,
  // and profile edits (budget/income) or a health refresh rebuild the view.
  final configFuture = ref.watch(promptConfigProvider.future);
  final healthFuture = ref.watch(monthlyHealthDataProvider.future);
  final expenses = ref.watch(expensesForAnalysisProvider);
  final location = ref.watch(locationForAnalysisProvider);
  final gameActivity = ref.watch(gameActivityForAnalysisProvider);
  final calendar = ref.watch(calendarForAnalysisProvider);
  final config = await configFuture;
  final healthFetch = await healthFuture;
  final snapshotContext = await loadAnalysisSnapshotContext(
    ref,
    period: period,
    selection: selection,
    config: config,
    calendar: calendar,
  );

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
    config: config,
    snapshotContext: snapshotContext,
  );
});
