import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import 'progress_review_charts.dart';
import 'progress_review_metrics.dart';
import 'progress_review_parser.dart';

class ProgressReviewDashboard extends StatelessWidget {
  const ProgressReviewDashboard({
    super.key,
    required this.rawMarkdown,
    this.generatedAt,
    this.title,
  });

  final String rawMarkdown;
  final DateTime? generatedAt;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final report = ProgressReviewParser.parse(rawMarkdown);
    if (report.isEmpty) {
      return Text(
        'Could not parse this progress review.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
      );
    }

    final metrics = ProgressReviewMetrics.fromReport(report);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null || generatedAt != null)
          _ReviewMetaStrip(title: title, generatedAt: generatedAt),
        if (metrics.overallScore != null ||
            metrics.adherenceTotal != null) ...[
          const SizedBox(height: 16),
          _HeroVisualCard(metrics: metrics),
        ],
        if (metrics.domainScores.length >= 3) ...[
          const SizedBox(height: 20),
          _ChartPanel(
            title: 'Domain radar',
            icon: Icons.radar_rounded,
            accent: context.palette.accent,
            child: DomainRadarChart(domains: metrics.domainScores),
          ),
        ],
        if (metrics.domainScores.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ChartPanel(
            title: 'Score breakdown',
            icon: Icons.stacked_bar_chart_rounded,
            accent: context.palette.accentAlt,
            child: DomainScoreBars(domains: metrics.domainScores),
          ),
        ],
        if (metrics.comparisons.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionLabel(
            title: 'Target vs actual',
            icon: Icons.compare_arrows_rounded,
            accent: context.palette.warning,
          ),
          const SizedBox(height: 12),
          ...metrics.comparisons.map(
            (metric) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ComparisonChartCard(metric: metric),
            ),
          ),
        ],
        if (metrics.highlights.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionLabel(
            title: 'What worked',
            icon: Icons.bolt_rounded,
            accent: AppColors.expenses,
          ),
          const SizedBox(height: 12),
          _MetricCarousel(
            metrics: metrics.highlights,
            positive: true,
          ),
        ],
        if (metrics.focusGaps.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionLabel(
            title: 'Gaps to close',
            icon: Icons.flag_rounded,
            accent: context.palette.warning,
          ),
          const SizedBox(height: 12),
          _MetricCarousel(
            metrics: metrics.focusGaps,
            positive: false,
          ),
        ],
      ],
    );
  }
}

class _ReviewMetaStrip extends StatelessWidget {
  const _ReviewMetaStrip({this.title, this.generatedAt});

  final String? title;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, color: palette.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                if (generatedAt != null)
                  Text(
                    DateFormat('d MMM yyyy · HH:mm')
                        .format(generatedAt!.toLocal()),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.textMuted,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroVisualCard extends StatelessWidget {
  const _HeroVisualCard({required this.metrics});

  final ProgressReviewMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final completed = metrics.adherenceCompleted ?? 0;
    final total = metrics.adherenceTotal ?? 0;
    final remaining = total - completed;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.accent.withValues(alpha: 0.12),
            palette.card,
            palette.accentAlt.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (metrics.overallScore != null)
                ScoreRingChart(
                  score: metrics.overallScore!,
                  size: 120,
                  stroke: 12,
                ),
              if (metrics.adherenceTotal != null)
                AdherenceDonut(
                  completed: completed,
                  total: total,
                  percent: metrics.adherencePercent,
                  size: 96,
                ),
            ],
          ),
          if (metrics.adherenceTotal != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AdherenceStatTile(
                    label: 'Completed',
                    value: '$completed',
                    color: palette.accentAlt,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdherenceStatTile(
                    label: 'Remaining',
                    value: '$remaining',
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AdherenceStatTile extends StatelessWidget {
  const _AdherenceStatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.cardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(title: title, icon: icon, accent: accent),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.icon,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.palette.textPrimary,
              ),
        ),
      ],
    );
  }
}

class _MetricCarousel extends StatelessWidget {
  const _MetricCarousel({
    required this.metrics,
    required this.positive,
  });

  final List<VisualBulletMetric> metrics;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: metrics.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => VisualMetricTile(
          metric: metrics[index],
          positive: positive,
        ),
      ),
    );
  }
}
