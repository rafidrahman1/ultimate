import 'package:flutter/material.dart';

import '../../core/analysis_period.dart';
import 'insight_models.dart';
import 'weekly_insights_dashboard.dart';

/// Back-compat wrapper — prefer [WeeklyInsightsDashboard] directly.
class InsightReportView extends StatelessWidget {
  const InsightReportView({
    super.key,
    required this.report,
    this.resultId = '',
    this.generatedAt,
    this.period,
    this.markdownOutput = '',
    this.userName,
    this.dataSources = const {},
  });

  final InsightReport report;
  final String resultId;
  final DateTime? generatedAt;
  final AnalysisPeriod? period;
  final String markdownOutput;
  final String? userName;
  final Map<String, String> dataSources;

  @override
  Widget build(BuildContext context) {
    final resolvedGeneratedAt = generatedAt ?? DateTime.now();
    final resolvedPeriod = period ??
        AnalysisPeriod.forReference(resolvedGeneratedAt);

    return WeeklyInsightsDashboard(
      report: report,
      resultId: resultId,
      generatedAt: resolvedGeneratedAt,
      period: resolvedPeriod,
      markdownOutput: markdownOutput,
      userName: userName,
      dataSources: dataSources,
    );
  }
}
