import 'package:flutter/material.dart';

import 'insight_models.dart';
import 'weekly_insights_dashboard.dart';

/// Back-compat wrapper — prefer [WeeklyInsightsDashboard] directly.
class InsightReportView extends StatelessWidget {
  const InsightReportView({
    super.key,
    required this.report,
    this.resultId = '',
    this.generatedAt,
    this.userName,
    this.dataSources = const {},
  });

  final InsightReport report;
  final String resultId;
  final DateTime? generatedAt;
  final String? userName;
  final Map<String, String> dataSources;

  @override
  Widget build(BuildContext context) {
    return WeeklyInsightsDashboard(
      report: report,
      resultId: resultId,
      generatedAt: generatedAt ?? DateTime.now(),
      userName: userName,
      dataSources: dataSources,
    );
  }
}
