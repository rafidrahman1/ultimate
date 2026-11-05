import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal/app/router.dart';
import 'package:personal/core/formatting.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/export/data_export_launcher.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_refresh.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/features/home/widgets/monthly_overview_card.dart';
import 'package:personal/features/home/widgets/setup_checklist_card.dart';
import 'package:personal/features/home/widgets/source_summary_card.dart';
import 'package:personal/shared/navigation/fade_scale_page_route.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/data_source_status_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeTileStatsProvider);
    final healthLoading = ref.watch(homeHealthLoadingProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final lastRefresh = ref.watch(homeLastRefreshProvider);

    return ContentWidth(
      child: RefreshIndicator(
        onRefresh: () async {
          final messenger = ScaffoldMessenger.of(context);
          final failed = await refreshAllSources(ref);
          if (failed.isEmpty) return;
          messenger.showSnackBar(
            SnackBar(content: Text("Couldn't refresh: ${failed.join(', ')}")),
          );
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.lg,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SetupChecklistCard(),
                    const MonthlyOverviewCard(),
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      children: [
                        Expanded(
                          child: Text('YOUR DATA', style: context.sectionLabel),
                        ),
                        Text(
                          lastRefresh == null
                              ? 'Pull down to refresh'
                              : 'Updated ${relativeTime(lastRefresh)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: context.palette.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen,
              ),
              sliver: SliverList.list(
                children: [
                  for (final row in _rows(homeFeatures)) ...[
                    if (row.first != homeFeatures.first)
                      const SizedBox(height: AppSpacing.sm),
                    row.length == 1
                        ? _card(context, row.first, stats, healthLoading, true)
                        : IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _card(
                                    context,
                                    row[0],
                                    stats,
                                    healthLoading,
                                    false,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _card(
                                    context,
                                    row[1],
                                    stats,
                                    healthLoading,
                                    false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ],
                ],
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.xxl,
                AppSpacing.screen,
                bottomInset + AppLayout.navPillClearance,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('TOOLS', style: context.sectionLabel),
                    const SizedBox(height: AppSpacing.sm),
                    _ToolButton(
                      icon: Icons.ios_share_rounded,
                      label: 'Export data',
                      onPressed: () => launchDataExport(context, ref),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pairs features two per row; Calendar (information-heavy) spans the full
/// width on its own row.
List<List<HomeFeature>> _rows(List<HomeFeature> features) {
  final rows = <List<HomeFeature>>[];
  final pending = <HomeFeature>[];
  for (final f in features) {
    if (f.id == HomeFeatureId.calendar) {
      if (pending.isNotEmpty) rows.add([...pending]);
      pending.clear();
      rows.add([f]);
    } else {
      pending.add(f);
      if (pending.length == 2) {
        rows.add([...pending]);
        pending.clear();
      }
    }
  }
  if (pending.isNotEmpty) rows.add([...pending]);
  return rows;
}

Widget _card(
  BuildContext context,
  HomeFeature feature,
  HomeTileStats stats,
  bool healthLoading,
  bool wide,
) {
  final loading = healthLoading && feature.id == HomeFeatureId.health;
  return SourceSummaryCard(
    label: feature.label,
    color: feature.colorFor(context),
    icon: feature.icon,
    stat: stats[feature.id],
    wide: wide,
    state: loading ? DataSourceState.loading : DataSourceState.available,
    emptyHint: 'Tap to set up or import',
    onPressed: () =>
        pushFadeScaleRoute(context, page: AppRoutes.screenFor(feature.route)),
  );
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: AppCard(
        tier: AppCardTier.flat,
        radius: AppRadii.card,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        onTap: onPressed,
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.palette.accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: context.palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
