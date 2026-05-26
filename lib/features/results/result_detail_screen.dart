import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'insight_dashboard_theme.dart';
import 'insight_parser.dart';
import 'results_service.dart';
import 'weekly_insights_dashboard.dart';

class ResultDetailScreen extends ConsumerWidget {
  const ResultDetailScreen({super.key, required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseTheme = Theme.of(context);
    final dashboardTheme = insightDashboardTheme(baseTheme);
    final report = parseInsightReport(result.output);
    final hasDashboard = report.hasRichLayout || report.sections.isNotEmpty;

    return Theme(
      data: dashboardTheme,
      child: Scaffold(
        backgroundColor: InsightDashboardColors.canvas,
        appBar: AppBar(
          title: const Text('Weekly Insights & Action Plan'),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copy insights',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result.output));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Insights copied'),
                    backgroundColor: InsightDashboardColors.cardElevated,
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
              WeeklyInsightsDashboard(
                report: report,
                resultId: result.id,
                generatedAt: result.createdAt,
                dataSources: result.dataSnapshot,
              )
            else
              _RawOutputFallback(output: result.output),
            const SizedBox(height: 20),
            _PromptPanel(prompt: result.prompt),
          ],
        ),
      ),
    );
  }
}

class _RawOutputFallback extends StatelessWidget {
  const _RawOutputFallback({required this.output});

  final String output;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: InsightDashboardColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InsightDashboardColors.border),
      ),
      child: Text(
        output,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: InsightDashboardColors.textSecondary,
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

    return Container(
      decoration: BoxDecoration(
        color: InsightDashboardColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InsightDashboardColors.border),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: InsightDashboardColors.textMuted,
          collapsedIconColor: InsightDashboardColors.textMuted,
          leading: const Icon(Icons.code, color: InsightDashboardColors.textMuted),
          title: Text(
            'Prompt used',
            style: theme.textTheme.titleSmall?.copyWith(
              color: InsightDashboardColors.textSecondary,
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: InsightDashboardColors.canvas,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: InsightDashboardColors.border),
              ),
              child: SelectableText(
                prompt,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.5,
                  color: InsightDashboardColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
