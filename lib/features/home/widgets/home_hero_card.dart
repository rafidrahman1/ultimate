import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal/core/period/analysis_month_settings_service.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/analysis/ui/analysis_month_picker.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Leads Home: which month is shown and how much data is loaded.
class HomeHeroCard extends ConsumerWidget {
  const HomeHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final month = ref.watch(selectedAnalysisMonthProvider);
    final stats = ref.watch(homeTileStatsProvider);

    final sources = homeFeatures;
    final loaded = sources.where((f) => stats[f.id] != null).length;

    return AppCard(
      tier: AppCardTier.hero,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label:
                      'Month ${DateFormat('MMMM yyyy').format(month)}. '
                      'Change month',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => pickAnalysisMonth(context, ref),
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MONTH', style: context.sectionLabel),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                DateFormat('MMMM yyyy').format(month),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.expand_more_rounded,
                              color: palette.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _CoverageBar(
            segments: [
              for (final f in sources)
                (color: f.colorFor(context), loaded: stats[f.id] != null),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            loaded == 0
                ? 'No data loaded for this month yet'
                : loaded == sources.length
                ? 'All your data is loaded'
                : '$loaded of ${sources.length} sources loaded',
            style: theme.textTheme.bodySmall,
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
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                height: 6,
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
