import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/features/results/legacy_insight_parser.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/features/results/insights_dashboard.dart';
import 'package:personal/features/results/insights_parser.dart';
import 'package:personal/features/results/legacy_insights_dashboard.dart';

class ResultDetailScreen extends ConsumerWidget {
  const ResultDetailScreen({super.key, required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final report = parseInsightReport(result.output);
    final insights = InsightsReportParser.parse(result.output);
    final hasInsightsDashboard = !insights.isEmpty;
    final hasLegacyDashboard =
        report.hasRichLayout || report.sections.isNotEmpty;
    final hasDashboard = hasInsightsDashboard || hasLegacyDashboard;

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Monthly Insights',
        extraActions: [
          AppBarCircularAction(
            icon: Icons.copy_outlined,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: result.output));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Insights copied'),
                  backgroundColor: palette.cardElevated,
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (hasDashboard)
            hasInsightsDashboard
                ? InsightsDashboard(
                    rawMarkdown: result.output,
                    resultId: result.id,
                    period: result.analysisPeriod,
                  )
                : LegacyInsightsDashboard(
                    report: report,
                    resultId: result.id,
                    generatedAt: result.createdAt,
                    period: result.analysisPeriod,
                    markdownOutput: result.output,
                    dataSources: result.dataSnapshot,
                  )
          else
            _RawOutputFallback(output: result.output),
          const SizedBox(height: 20),
          _PromptPanel(prompt: result.prompt),
        ],
      ),
    );
  }
}
