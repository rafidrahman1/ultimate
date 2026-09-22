import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/export/export_markdown_builder.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/results/analysis_snapshot_builder.dart';

final dataExportServiceProvider = Provider<DataExportService>(
  (ref) => DataExportService(ref),
);

/// Gathers the same per-source data the analysis pipeline uses and renders
/// it into a raw markdown export. Does not make any AI network call.
class DataExportService {
  DataExportService(this._ref);

  final Ref _ref;

  Future<({String markdown, AnalysisPeriod period})> buildRawMarkdown(
    AnalysisSourceSelection selection,
  ) async {
    final config = await _ref.read(promptConfigProvider.future);
    final period = _ref.read(analysisPeriodProvider);
    final expenses = _ref.read(expensesForAnalysisProvider);
    final location = _ref.read(locationForAnalysisProvider);
    final gameActivity = _ref.read(gameActivityForAnalysisProvider);
    final calendar = _ref.read(calendarForAnalysisProvider);
    final calendarUpcoming = _ref.read(calendarForDisplayProvider);
    final monthlyHealth = await _ref.read(monthlyHealthDataProvider.future);
    final monthlySummary = MonthlyHealthSummary.fromFetch(monthlyHealth);

    final snapshotContext = await loadAnalysisSnapshotContext(
      _ref,
      period: period,
      selection: selection,
      config: config,
      calendar: calendar,
    );
    final dataSnapshot = buildDataSnapshot(
      selection: selection,
      monthlySummary: monthlySummary,
      expenses: expenses,
      location: location,
      gameActivity: gameActivity,
      calendar: calendar,
      calendarUpcomingSource: calendarUpcoming,
      period: period,
      workAddress: config.workAddress,
      workHours: config.workHours,
      weekendDays: config.weekendDays,
      context: snapshotContext,
    );

    final markdown = buildExportMarkdown(
      dataSnapshot: dataSnapshot,
      period: period,
      generatedAt: DateTime.now(),
    );
    return (markdown: markdown, period: period);
  }
}
