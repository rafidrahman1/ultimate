import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/dashboard_view_data.dart';
import 'package:personal/features/progress_review/progress_review_charts.dart';

class DashboardCoverageHeader extends StatelessWidget {
  const DashboardCoverageHeader({
    super.key,
    required this.data,
  });

  final DashboardViewData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analysis overview',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.periodLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  data.hasAnyData
                      ? '${data.loadedSourceCount} of ${data.totalSourceCount} sources · pre-computed metrics'
                      : 'Load data from Home tiles to populate analysis metrics',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          AdherenceDonut(
            completed: data.loadedSourceCount,
            total: data.totalSourceCount,
            size: 96,
          ),
        ],
      ),
    );
  }
}

class DashboardDomainGrid extends StatelessWidget {
  const DashboardDomainGrid({
    super.key,
    required this.domains,
    required this.colorFor,
  });

  final List<DashboardDomainStatus> domains;
  final Color Function(String domainId) colorFor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 520 ? 3 : 2;
        final itemWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * 10) / crossAxisCount;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final domain in domains)
              SizedBox(
                width: itemWidth,
                child: _DomainStatusTile(
                  domain: domain,
                  color: colorFor(domain.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DomainStatusTile extends StatelessWidget {
  const _DomainStatusTile({
    required this.domain,
    required this.color,
  });

  final DashboardDomainStatus domain;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final muted = !domain.hasData;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: muted ? palette.border : color.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconForDomain(domain.iconName),
                size: 18,
                color: muted ? palette.textMuted : color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  domain.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: muted ? palette.textMuted : palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            domain.headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: muted ? palette.textSecondary : color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            domain.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardSectionCard extends StatelessWidget {
  const DashboardSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class DashboardHorizontalBars extends StatelessWidget {
  const DashboardHorizontalBars({
    super.key,
    required this.items,
    required this.color,
    this.emptyLabel = 'No data',
  });

  final List<DashboardBarItem> items;
  final Color color;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        emptyLabel,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.palette.textMuted,
            ),
      );
    }

    final maxValue = items
        .map((item) => item.value)
        .fold<double>(0, (max, value) => math.max(max, value));

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _HorizontalBarRow(
            item: items[i],
            maxValue: maxValue,
            color: color,
          ),
        ],
      ],
    );
  }
}

class _HorizontalBarRow extends StatelessWidget {
  const _HorizontalBarRow({
    required this.item,
    required this.maxValue,
    required this.color,
  });

  final DashboardBarItem item;
  final double maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final factor = maxValue == 0 ? 0.0 : (item.value / maxValue).clamp(0.04, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.displayValue,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: factor,
            minHeight: 10,
            backgroundColor: palette.border,
            color: color,
          ),
        ),
      ],
    );
  }
}

class DashboardColumnChart extends StatelessWidget {
  const DashboardColumnChart({
    super.key,
    required this.items,
    required this.color,
    this.height = 160,
    this.targetLine,
  });

  final List<DashboardBarItem> items;
  final Color color;
  final double height;
  final double? targetLine;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final palette = context.palette;
    final maxValue = items
        .map((item) => item.value)
        .fold<double>(0, (max, value) => math.max(max, value));

    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _ColumnBar(
                item: items[i],
                maxValue: maxValue,
                color: color,
                targetLine: targetLine,
                palette: palette,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ColumnBar extends StatelessWidget {
  const _ColumnBar({
    required this.item,
    required this.maxValue,
    required this.color,
    required this.targetLine,
    required this.palette,
  });

  final DashboardBarItem item;
  final double maxValue;
  final Color color;
  final double? targetLine;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final factor = maxValue == 0 ? 0.0 : (item.value / maxValue).clamp(0.0, 1.0);
    final hasValue = item.value > 0;
    final barColor = hasValue ? color : palette.border;

    return SizedBox(
      width: 34,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (hasValue)
            Text(
              item.displayValue,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
            )
          else
            const SizedBox(height: 12),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barHeight = constraints.maxHeight * factor;
                final targetHeight = targetLine == null || maxValue == 0
                    ? null
                    : constraints.maxHeight *
                        (targetLine! / maxValue).clamp(0.0, 1.0);

                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    if (targetHeight != null)
                      Positioned(
                        bottom: targetHeight,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 1.5,
                          color: palette.warning.withValues(alpha: 0.7),
                        ),
                      ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 22,
                        height: math.max(barHeight, hasValue ? 6 : 4),
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardMetricRow extends StatelessWidget {
  const DashboardMetricRow({
    super.key,
    required this.metrics,
  });

  final List<({String label, String value, Color color})> metrics;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0)
            Container(
              width: 1,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: palette.border,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metrics[i].label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  metrics[i].value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: metrics[i].color,
                      ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class DashboardStableMonthCard extends StatelessWidget {
  const DashboardStableMonthCard({
    super.key,
    required this.section,
  });

  final DashboardStableMonthSection section;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final accent = !section.canEvaluate
        ? palette.textMuted
        : section.isStable
            ? AppSemanticColors.health(context)
            : palette.warning;
    final statusLabel = !section.canEvaluate
        ? 'Needs health + expenses'
        : section.isStable
            ? 'Stable month'
            : 'Unstable month';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                section.isStable && section.canEvaluate
                    ? Icons.verified_rounded
                    : Icons.fact_check_outlined,
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Healthy month detection',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (section.canEvaluate) ...[
            const SizedBox(height: 16),
            DashboardMetricRow(
              metrics: [
                (
                  label: 'Short nights',
                  value: '${section.shortSleepNights}',
                  color: accent,
                ),
                (
                  label: 'Sleep debt',
                  value: '${section.sleepDebtHours.toStringAsFixed(1)} h',
                  color: accent,
                ),
                (
                  label: 'Top category',
                  value: section.largestCategoryName ?? '—',
                  color: AppSemanticColors.expenses(context),
                ),
              ],
            ),
            if (section.hasSevereAnomalyCluster &&
                section.severeClusterLabel != null) ...[
              const SizedBox(height: 12),
              Text(
                'Severe cluster: ${section.severeClusterLabel}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class DashboardAnomalyList extends StatelessWidget {
  const DashboardAnomalyList({
    super.key,
    required this.anomalies,
    required this.color,
  });

  final List<DashboardAnomalyItem> anomalies;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (anomalies.isEmpty) {
      return Text(
        'No ranked anomaly candidates for this period.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.palette.textMuted,
            ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < anomalies.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _AnomalyBarRow(anomaly: anomalies[i], color: color),
        ],
      ],
    );
  }
}

class _AnomalyBarRow extends StatelessWidget {
  const _AnomalyBarRow({
    required this.anomaly,
    required this.color,
  });

  final DashboardAnomalyItem anomaly;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const maxSeverity = 10.0;
    final factor = (anomaly.severity / maxSeverity).clamp(0.04, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                anomaly.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'S${anomaly.severity}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: factor,
            minHeight: 10,
            backgroundColor: palette.border,
            color: color,
          ),
        ),
      ],
    );
  }
}

IconData _iconForDomain(String iconName) {
  return switch (iconName) {
    'health' => Icons.monitor_heart_outlined,
    'expenses' => Icons.account_balance_wallet_outlined,
    'location' => Icons.route_outlined,
    'gaming' => Icons.sports_esports_outlined,
    'calendar' => Icons.calendar_month_outlined,
    _ => Icons.insights_outlined,
  };
}
