import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_result_period.dart';
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

class _RawOutputFallback extends StatelessWidget {
  const _RawOutputFallback({required this.output});

  final String output;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        output,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
              height: 1.5,
            ),
      ),
    );
  }
}

class _PromptPanel extends StatelessWidget {
  const _PromptPanel({required this.prompt});

  final String prompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: palette.textMuted,
          collapsedIconColor: palette.textMuted,
          leading: Icon(Icons.code, color: palette.textMuted),
          title: Text(
            'Prompt used',
            style: theme.textTheme.titleSmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.canvas,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: SelectableText(
                prompt,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.5,
                  color: palette.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
