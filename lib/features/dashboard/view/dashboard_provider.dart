import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/period/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/analysis/ui/analysis_data_preview.dart';
import 'package:personal/features/dashboard/view/dashboard_cache.dart';
import 'package:personal/features/dashboard/view/dashboard_view_data.dart';
import 'package:personal/features/health/data/health_service.dart';
import 'package:personal/features/health/data/health_summary.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/results/pipeline/analysis_snapshot_builder.dart';
import 'package:personal/features/screen_time/data/screen_time_service.dart';

/// Last saved dashboard for the selected month, shown until the live one is
/// ready (cold start) so the tiles never vanish.
final dashboardCachedProvider = FutureProvider<DashboardViewData?>(
  (ref) => DashboardCache.load(ref.watch(analysisPeriodProvider)),
);

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
  final screenFuture = ref.watch(screenTimeForAnalysisProvider.future);
  final config = await configFuture;
  // The previous-month health read is the slowest step; run it alongside the
  // current-month and screen-time reads instead of after them.
  final contextFuture = loadAnalysisSnapshotContext(
    ref,
    period: period,
    selection: selection,
    config: config,
    calendar: calendar,
  );
  final healthFetch = await healthFuture;
  final screenTime = await screenFuture;
  final snapshotContext = await contextFuture;

  final healthSummary = healthFetch.hasData
      ? MonthlyHealthSummary.fromFetch(healthFetch)
      : null;

  final view = buildDashboardViewData(
    period: period,
    healthSummary: healthSummary,
    expenses: expenses,
    location: location,
    gameActivity: gameActivity,
    calendar: calendar,
    config: config,
    snapshotContext: snapshotContext,
    screenTimeData: screenTime,
  );
  unawaited(DashboardCache.save(view));
  return view;
});
