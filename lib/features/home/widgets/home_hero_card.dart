import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/home/analysis_month_picker.dart';
import 'package:personal/features/home/analyze_options_dialog.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_summary_providers.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/features/results/analysis_service.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Leads Home: which month is analysed, how much data is loaded, the main
/// Analyze action and this week's checklist progress.
class HomeHeroCard extends ConsumerWidget {
  const HomeHeroCard({
    super.key,
    required this.onOpenChecklist,
    required this.onOpenReports,
  });

  final VoidCallback onOpenChecklist;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final month = ref.watch(selectedAnalysisMonthProvider);
    final stats = ref.watch(homeTileStatsProvider);
    final isRunning = ref.watch(
      analysisRunProvider.select((state) => state.isRunning),
    );
    final checklist = ref.watch(homeChecklistSummaryProvider);

    final sources = homeFeatures
        .where((f) => f.id != HomeFeatureId.dashboard)
        .toList();
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
                      'Analysis month ${DateFormat('MMMM yyyy').format(month)}. '
                      'Change month',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => pickAnalysisMonth(context, ref),
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ANALYSIS MONTH', style: context.sectionLabel),
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
              const SizedBox(width: AppSpacing.md),
              Builder(
                builder: (buttonContext) => FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => showAnalyzeOptionsDialog(
                    context: context,
                    ref: ref,
                    buttonContext: buttonContext,
                  ),
                  icon: isRunning
                      ? SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(isRunning ? 'Running' : 'Analyze'),
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
                : '$loaded of ${sources.length} sources loaded',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: palette.border.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.xs),
          if (checklist != null)
            _ChecklistStrip(summary: checklist, onTap: onOpenChecklist)
          else
            Text(
              'Run monthly insights to get a weekly checklist.',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenReports,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.insights_rounded, size: 18),
              label: const Text('Past reports'),
            ),
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
            if (i > 0) const SizedBox(width: 4),
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

class _ChecklistStrip extends StatelessWidget {
  const _ChecklistStrip({required this.summary, required this.onTap});

  final ChecklistSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = context.statusColors;
    final complete = summary.total > 0 && summary.done >= summary.total;

    return Semantics(
      button: true,
      label:
          'Week ${summary.weekNumber} checklist, ${summary.done} of '
          '${summary.total} done. Open checklist',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.small),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Week ${summary.weekNumber} · ${summary.monthLabel}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    summary.total == 0
                        ? 'No actions'
                        : '${summary.done}/${summary.total} done',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: complete ? status.good : null,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: summary.fraction),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    color: complete ? status.good : theme.colorScheme.primary,
                    backgroundColor: context.palette.border,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
