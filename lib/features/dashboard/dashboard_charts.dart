import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/ring_gauge.dart';

export 'package:personal/shared/widgets/ring_gauge.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/dashboard_view_data.dart';

class DashboardCoverageHeader extends StatelessWidget {
  const DashboardCoverageHeader({super.key, required this.data});

  final DashboardViewData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final accent = palette.accent;
    final stable = data.stableMonth;
    final verdict = stable == null || !stable.canEvaluate
        ? '${data.loadedSourceCount} of ${data.totalSourceCount} sources'
        : stable.isStable
        ? 'Stable month'
        : 'Unstable month';
    final verdictColor = stable != null && stable.canEvaluate
        ? (stable.isStable
              ? AppSemanticColors.health(context)
              : palette.warning)
        : palette.textPrimary;

    return AppCard(
      tier: AppCardTier.hero,
      accent: accent,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.space_dashboard_rounded, size: 18, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'ANALYSIS OVERVIEW',
                  style: context.sectionLabel.copyWith(color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              verdict,
              style: context.statDisplay.copyWith(
                fontSize: 32,
                color: verdictColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.periodLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _CoverageBar(domains: data.domains),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${data.loadedSourceCount} of ${data.totalSourceCount} sources loaded'
            '${stable != null && stable.canEvaluate && stable.shortSleepNights > 0 ? ' · ${stable.shortSleepNights} short nights' : ''}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One segment per source, lit in its domain colour when data is loaded.
class _CoverageBar extends StatelessWidget {
  const _CoverageBar({required this.domains});

  final List<DashboardDomainStatus> domains;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label:
          '${domains.where((d) => d.hasData).length} of ${domains.length} sources loaded',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < domains.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Tooltip(
                message:
                    '${domains[i].label}: ${domains[i].hasData ? 'loaded' : 'no data'}',
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: domains[i].hasData
                        ? AppSemanticColors.forDomainName(
                            domains[i].id,
                            context,
                          )
                        : palette.border,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
            ),
          ],
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
    this.onOpen,
  });

  static const _tileHeight = 140.0;
  static const _spacing = 10.0;

  final List<DashboardDomainStatus> domains;
  final Color Function(String domainId) colorFor;

  /// Called with the domain id when a tile is tapped.
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 520 ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: domains.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: MediaQuery.textScalerOf(context).scale(_tileHeight),
            crossAxisSpacing: _spacing,
            mainAxisSpacing: _spacing,
          ),
          itemBuilder: (context, index) {
            final domain = domains[index];
            return _DomainStatusTile(
              domain: domain,
              color: colorFor(domain.id),
              onTap: onOpen == null ? null : () => onOpen!(domain.id),
            );
          },
        );
      },
    );
  }
}

class _DomainStatusTile extends StatelessWidget {
  const _DomainStatusTile({
    required this.domain,
    required this.color,
    this.onTap,
  });

  final DashboardDomainStatus domain;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final muted = !domain.hasData;
    final tone = muted ? palette.textMuted : color;

    return Semantics(
      container: true,
      button: onTap != null,
      label: '${domain.label}: ${domain.headline}. ${domain.detail}',
      excludeSemantics: true,
      child: AppCard(
        tier: muted ? AppCardTier.flat : AppCardTier.raised,
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: AppOpacity.medium),
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: Icon(
                    _iconForDomain(domain.iconName),
                    size: 16,
                    color: tone,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    domain.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: muted ? palette.textMuted : palette.textPrimary,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: palette.textMuted,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              domain.headline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: muted ? palette.textSecondary : color,
              ),
            ),
            const Spacer(),
            Text(
              domain.detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
                height: 1.3,
              ),
            ),
          ],
        ),
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

    return AppCard(
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
                  borderRadius: BorderRadius.circular(AppRadii.card),
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
              Tooltip(
                message: 'Hold the card to reorder',
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: palette.textMuted,
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
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.palette.textMuted),
      );
    }

    final maxValue = items
        .map((item) => item.value)
        .fold<double>(0, (max, value) => math.max(max, value));

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _HorizontalBarRow(item: items[i], maxValue: maxValue, color: color),
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
    final factor = maxValue == 0
        ? 0.0
        : (item.value / maxValue).clamp(0.04, 1.0);

    return Semantics(
      label: '${item.label}: ${item.displayValue}',
      excludeSemantics: true,
      child: Column(
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
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: factor),
              duration: _chartDuration(context),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: palette.border,
                color: color,
              ),
            ),
          ),
        ],
      ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Roomy bars with value labels when they fit; otherwise squeeze every
        // bar into the width (no sideways scrolling) and rely on tap-to-read.
        const roomyWidth = 34.0;
        const roomyGap = 8.0;
        final roomyTotal =
            items.length * roomyWidth + (items.length - 1) * roomyGap;
        final compact = roomyTotal > constraints.maxWidth;
        final gap = compact ? 3.0 : roomyGap;
        final barSlot = compact
            ? (constraints.maxWidth - gap * (items.length - 1)) / items.length
            : roomyWidth;
        final labelEvery = compact ? math.max(1, (items.length / 6).ceil()) : 1;

        return SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                _ColumnBar(
                  item: items[i],
                  maxValue: maxValue,
                  color: color,
                  targetLine: targetLine,
                  palette: palette,
                  slotWidth: barSlot,
                  compact: compact,
                  showLabel: i % labelEvery == 0,
                ),
              ],
            ],
          ),
        );
      },
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
    required this.slotWidth,
    required this.compact,
    required this.showLabel,
  });

  final DashboardBarItem item;
  final double maxValue;
  final Color color;
  final double? targetLine;
  final AppPalette palette;
  final double slotWidth;
  final bool compact;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final factor = maxValue == 0
        ? 0.0
        : (item.value / maxValue).clamp(0.0, 1.0);
    final hasValue = item.value > 0;
    final barColor = hasValue ? color : palette.border;
    final barWidth = compact ? slotWidth : 22.0;

    return Semantics(
      label: '${item.label}: ${item.displayValue}',
      excludeSemantics: true,
      child: SizedBox(
        width: slotWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!compact) ...[
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
            ],
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
                    clipBehavior: Clip.none,
                    children: [
                      if (targetHeight != null)
                        Positioned(
                          bottom: targetHeight,
                          left: compact ? -1.5 : 0,
                          right: compact ? -1.5 : 0,
                          child: Container(
                            height: 1.5,
                            color: palette.warning.withValues(alpha: 0.7),
                          ),
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Tooltip(
                          message: '${item.label}: ${item.displayValue}',
                          triggerMode: TooltipTriggerMode.tap,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: math.max(barHeight, hasValue ? 6 : 4),
                            ),
                            duration: _chartDuration(context),
                            curve: Curves.easeOutCubic,
                            builder: (context, height, _) => Container(
                              width: barWidth,
                              height: height,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(compact ? 2 : 4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 12,
              child: showLabel
                  ? OverflowBox(
                      maxWidth: 40,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Key figures as small tinted tiles. With [vertical] they stack as
/// label/value rows (used beside a [RingGauge]).
class DashboardMetricRow extends StatelessWidget {
  const DashboardMetricRow({
    super.key,
    required this.metrics,
    this.vertical = false,
  });

  final List<({String label, String value, Color color})> metrics;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    if (vertical) {
      return Column(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0) Divider(height: AppSpacing.lg, color: palette.border),
            MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      metrics[i].label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: palette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        metrics[i].value,
                        maxLines: 1,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: metrics[i].color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    // Tiles are single-line, so they match in height without stretching
    // (stretch needs a bounded height, which a card's Column doesn't give).
    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: MergeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: metrics[i].color.withValues(alpha: AppOpacity.subtle),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metrics[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        metrics[i].value,
                        maxLines: 1,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: metrics[i].color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A percentage ring with its label, followed by supporting metrics.
/// Falls back to a plain metric row when [percent] is null.
class DashboardLeadRow extends StatelessWidget {
  const DashboardLeadRow({
    super.key,
    required this.percent,
    required this.ringLabel,
    required this.ringColor,
    required this.metrics,
  });

  final double? percent;
  final String ringLabel;
  final Color ringColor;
  final List<({String label, String value, Color color})> metrics;

  @override
  Widget build(BuildContext context) {
    final value = percent;
    if (value == null) return DashboardMetricRow(metrics: metrics);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RingGauge(percent: value, color: ringColor, label: ringLabel),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: DashboardMetricRow(metrics: metrics, vertical: true)),
      ],
    );
  }
}

class DashboardStableMonthCard extends StatelessWidget {
  const DashboardStableMonthCard({super.key, required this.section});

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

    return AppCard(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: palette.border),
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

/// Entry animation length for charts; instant when the system asks for
/// reduced motion.
Duration _chartDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 650);
