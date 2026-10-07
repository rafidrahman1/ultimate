import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/ring_gauge.dart';

export 'package:personal/shared/widgets/ring_gauge.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/core/formatting.dart';
import 'package:personal/features/dashboard/dashboard_layout_service.dart';
import 'package:personal/features/dashboard/dashboard_view_data.dart';

part 'dashboard_bar_charts.dart';
part 'dashboard_headline.dart';
part 'dashboard_metric_widgets.dart';

class DashboardCoverageHeader extends StatelessWidget {
  const DashboardCoverageHeader({
    super.key,
    required this.data,
    required this.onOpenCard,
  });

  final DashboardViewData data;

  /// Called when a headline figure is tapped.
  final ValueChanged<DashboardCardId> onOpenCard;

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
          DashboardHeadlineGrid(
            stats: dashboardHeadlineStats(context, data),
            onOpen: onOpenCard,
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

/// A collapsible analysis card: [summary] is always shown, [details] only
/// once the user expands it (remembered across launches).
class DashboardSectionCard extends ConsumerWidget {
  const DashboardSectionCard({
    super.key,
    required this.cardId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.summary,
    this.details,
    this.delta,
  });

  final DashboardCardId cardId;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget summary;
  final Widget? details;
  final DashboardDelta? delta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final hasDetails = details != null;
    final expanded =
        hasDetails &&
        ref.watch(dashboardExpandedCardsProvider).contains(cardId);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);

    final header = Row(
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
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (delta != null) ...[
                    const SizedBox(width: 8),
                    DashboardDeltaChip(delta: delta!),
                  ],
                ],
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
        if (hasDetails)
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: duration,
            child: Icon(
              Icons.expand_more_rounded,
              size: 24,
              color: palette.textMuted,
            ),
          ),
      ],
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasDetails)
            Semantics(
              button: true,
              expanded: expanded,
              label: '$title. ${expanded ? 'Hide' : 'Show'} details',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.card),
                onTap: () => ref
                    .read(dashboardExpandedCardsProvider.notifier)
                    .toggle(cardId),
                child: header,
              ),
            )
          else
            header,
          const SizedBox(height: 18),
          summary,
          AnimatedSize(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: details,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
