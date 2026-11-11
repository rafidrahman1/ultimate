import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/period/analysis_month_settings_service.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_refresh.dart';
import 'package:personal/features/home/home_tile_stats.dart';
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
    final now = clock.now();
    final isCurrent = month.year == now.year && month.month == now.month;
    final partial = isCurrent
        ? '1–${now.day} ${DateFormat('MMM').format(month)} so far'
        : 'Full month';

    final summary = switch (withData.length) {
      0 => 'Nothing imported for this month yet.',
      final n when n == homeFeatures.length => 'Every source has data.',
      final n => '$n of ${homeFeatures.length} sources have data.',
    };

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${month.year} · ${partial.toUpperCase()}',
            style: context.sectionLabel,
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              DateFormat('MMMM').format(month),
              maxLines: 1,
              style: theme.textTheme.displayMedium?.copyWith(
                fontSize: 52,
                height: 1,
                letterSpacing: -1.8,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _CoverageBar(
            segments: [
              for (final f in homeFeatures)
                (color: f.colorFor(context), loaded: stats[f.id] != null),
            ],
          ),
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
                height: 3,
                color: segments[i].loaded ? segments[i].color : track,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
