import 'package:flutter/material.dart';

import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/results/insight_checklist_service.dart';
import 'package:personal/features/results/insight_detail_overlay.dart';
import 'package:personal/features/results/insight_rich_text.dart';
import 'package:personal/features/results/insights_models.dart';
import 'package:personal/features/results/insights_parser.dart';
import 'package:personal/features/results/weekly_checklist_panel.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/shared/widgets/checklist_status_circle.dart';

part 'insights_action_list.dart';
part 'insights_visuals.dart';

/// Premium dark dashboard for structured AI insight markdown.
class InsightsDashboard extends StatelessWidget {
  const InsightsDashboard({
    super.key,
    required this.rawMarkdown,
    required this.resultId,
    this.checklistSource,
    required this.period,
    this.padding = EdgeInsets.zero,
  });

  final String rawMarkdown;
  final String resultId;
  final AnalysisResult? checklistSource;
  final AnalysisPeriod period;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final report = InsightsReportParser.parse(rawMarkdown);
    if (report.isEmpty) {
      return Padding(
        padding: padding,
        child: Text(
          'No structured insights to display.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      );
    }

    final checklistMonth = period.checklistMonthLabel;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (report.anomalies.isNotEmpty) ...[
            _SectionHeading(
              title: 'Patterns & anomalies',
              icon: Icons.auto_graph_rounded,
              accent: context.palette.warning,
            ),
            const SizedBox(height: 14),
            ...report.anomalies.map(_AnomalyCard.new),
          ],
          if (report.actions.isNotEmpty) ...[
            if (report.anomalies.isNotEmpty) const SizedBox(height: 32),
            _SectionHeading(
              title: '$checklistMonth checklist',
              subtitle: 'One segment per week',
              icon: Icons.playlist_add_check_rounded,
              accent: context.palette.accent,
            ),
            const SizedBox(height: 14),
            WeeklyChecklistPanel(
              resultId: resultId,
              checklistSource: checklistSource,
              period: period,
              report: report,
              monthLabel: checklistMonth,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.icon,
    required this.accent,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.palette.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: context.palette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AnomalyCard extends StatelessWidget {
  const _AnomalyCard(this.anomaly);

  final InsightAnomaly anomaly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = _AnomalyVisual.forAnomaly(anomaly, context.palette);
    final combined = '${anomaly.title} ${anomaly.description}';

    final detailBody = anomaly.description.isNotEmpty
        ? anomaly.description
        : anomaly.title;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InsightLongPressCard(
        detailTitle: anomaly.title,
        detailBody: detailBody,
        accent: visual.accent,
        icon: visual.icon,
        child: Card(
          margin: EdgeInsets.zero,
          color: context.palette.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.cardLarge),
            side: BorderSide(color: visual.borderColor, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: visual.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.cardLarge),
                  ),
                  child: Icon(visual.icon, color: visual.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              anomaly.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: context.palette.textPrimary,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CategoryChip(
                            label: anomaly.category,
                            color: visual.accent,
                          ),
                        ],
                      ),
                      if (anomaly.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        HighlightedInsightText(
                          text: anomaly.description,
                          highlightColor: visual.accent,
                          maxLines: 1,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.palette.textSecondary,
                            height: 1.55,
                          ),
                        ),
                      ],
                      if (_extractHighlights(combined).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _extractHighlights(combined)
                              .take(4)
                              .map(
                                (h) =>
                                    _MetricChip(label: h, color: visual.accent),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<InsightItemCategory> _categoriesFor(List<ActionDirective> directives) {
  final seen = <InsightItemCategory>{};
  for (final action in directives) {
    seen.add(action.categoryEnum);
  }
  const order = [
    InsightItemCategory.health,
    InsightItemCategory.expenses,
    InsightItemCategory.transport,
    InsightItemCategory.gaming,
    InsightItemCategory.calendar,
    InsightItemCategory.general,
  ];
  return order.where(seen.contains).toList();
}

String? _groupHeaderFor(
  List<ActionDirective> directives,
  InsightItemCategory category,
) {
  for (final action in directives) {
    if (action.categoryEnum != category) continue;
    if (action.groupLabel != null && action.groupLabel!.isNotEmpty) {
      return action.groupLabel;
    }
  }
  return null;
}

int _globalOffsetForCategory(
  List<ActionDirective> directives,
  List<InsightItemCategory> categories,
  int tabIndex,
) {
  var offset = 0;
  for (var i = 0; i < tabIndex; i++) {
    offset += directives.where((a) => a.categoryEnum == categories[i]).length;
  }
  return offset;
}
