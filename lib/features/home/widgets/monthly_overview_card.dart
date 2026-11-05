import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/period/analysis_month_settings_service.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_refresh.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/data_freshness_indicator.dart';

/// Leads Home: which month, how many sources have data, when everything was
/// last refreshed, and the headline figure from each source that has one.
class MonthlyOverviewCard extends ConsumerWidget {
  const MonthlyOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final month = ref.watch(selectedAnalysisMonthProvider);
    final stats = ref.watch(homeTileStatsProvider);
    final loadingHealth = ref.watch(homeHealthLoadingProvider);
    final lastRefresh = ref.watch(homeLastRefreshProvider);

    final withData = [
      for (final f in homeFeatures)
        if (stats[f.id] != null) f,
    ];
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;
    final partial = isCurrent
        ? '1–${now.day} ${DateFormat('MMM').format(month)} so far'
        : 'Full month';

    final summary = switch (withData.length) {
      0 => 'Nothing imported for this month yet.',
      final n when n == homeFeatures.length => 'Every source has data.',
      final n => '$n of ${homeFeatures.length} sources have data.',
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(month),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Text(partial, style: context.sectionLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _CoverageBar(
            segments: [
              for (final f in homeFeatures)
                (color: f.colorFor(context), loaded: stats[f.id] != null),
            ],
          ),
          if (withData.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: [
                for (final f in withData.take(4))
                  _Metric(
                    label: f.label,
                    value: stats[f.id]!.value,
                    caption: stats[f.id]!.caption,
                    color: f.colorFor(context),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DataFreshnessIndicator(
                  updatedAt: lastRefresh,
                  refreshing: loadingHealth,
                  prefix: 'Last refresh',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Semantics(
      label: '$label $value $caption',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: context.statDisplay.copyWith(
                  fontSize: 17,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                caption,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverageBar extends StatelessWidget {
  const _CoverageBar({required this.segments});

  final List<({Color color, bool loaded})> segments;

  @override
  Widget build(BuildContext context) {
    final track = context.palette.border;
    final animate = !MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AnimatedContainer(
                duration: animate
                    ? const Duration(milliseconds: 400)
                    : Duration.zero,
                curve: Curves.easeOutCubic,
                height: 4,
                decoration: BoxDecoration(
                  color: segments[i].loaded ? segments[i].color : track,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
