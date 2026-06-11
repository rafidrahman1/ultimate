import 'package:flutter/material.dart';

import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/results/insight_detail_overlay.dart';
import 'package:personal/features/results/insight_rich_text.dart';
import 'package:personal/features/results/insights_models.dart';
import 'package:personal/features/results/insights_parser.dart';

/// Premium dark dashboard for structured AI insight markdown.
class InsightsDashboard extends StatelessWidget {
  const InsightsDashboard({
    super.key,
    required this.rawMarkdown,
    required this.resultId,
    required this.period,
    this.padding = EdgeInsets.zero,
  });

  final String rawMarkdown;
  final String resultId;
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

    final detailBody =
        anomaly.description.isNotEmpty ? anomaly.description : anomaly.title;

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
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: visual.borderColor, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: visual.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
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
                                (h) => _MetricChip(
                                  label: h,
                                  color: visual.accent,
                                ),
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.palette.border.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.replaceAll('**', ''),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _AnomalyVisual {
  const _AnomalyVisual({
    required this.icon,
    required this.accent,
    required this.borderColor,
  });

  final IconData icon;
  final Color accent;
  final Color borderColor;

  factory _AnomalyVisual.forAnomaly(InsightAnomaly anomaly, AppPalette palette) {
    final text = '${anomaly.title} ${anomaly.description}'.toLowerCase();

    if (_containsAny(text, const [
      'financial',
      'hemorrhage',
      'expense',
      'spending',
      'discretionary',
      'salary',
      'runway',
      'gift',
    ])) {
      final alert = text.contains('hemorrhage') || text.contains('critically');
      return _AnomalyVisual(
        icon: alert ? Icons.warning_amber_rounded : Icons.account_balance_wallet_rounded,
        accent: palette.expenses,
        borderColor: palette.expenses.withValues(alpha: 0.45),
      );
    }

    if (_containsAny(text, const [
      'vespa',
      'fuel',
      'economy',
      'mileage',
      'carburetor',
      'transport',
      'mobility',
      'motorcycle',
      'location',
    ])) {
      return _AnomalyVisual(
        icon: text.contains('fuel') || text.contains('octane')
            ? Icons.local_gas_station_rounded
            : Icons.moped_rounded,
        accent: palette.mobility,
        borderColor: palette.mobility.withValues(alpha: 0.4),
      );
    }

    if (_containsAny(text, const [
      'sleep',
      'cardiovascular',
      'neat',
      'heart',
    ])) {
      final useBed = text.contains('sleep') || text.contains('bedtime');
      return _AnomalyVisual(
        icon: useBed ? Icons.bedtime_rounded : Icons.favorite_rounded,
        accent: useBed ? palette.warning : palette.health,
        borderColor: (useBed ? palette.warning : palette.health).withValues(alpha: 0.4),
      );
    }

    return _AnomalyVisual(
      icon: Icons.insights_rounded,
      accent: palette.accent,
      borderColor: palette.border,
    );
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}

List<String> _extractHighlights(String text) {
  final highlights = <String>[];
  final seen = <String>{};
  for (final match in RegExp(r'\*\*([^*]+)\*\*').allMatches(text)) {
    final value = match.group(1)?.trim() ?? '';
    if (value.isEmpty) continue;
    final key = value.toLowerCase();
    if (seen.contains(key)) continue;
    if (!RegExp(r'\d').hasMatch(value)) continue;
    seen.add(key);
    highlights.add(value);
  }
  return highlights;
}
