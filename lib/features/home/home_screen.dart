import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/formatting.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/home/home_refresh.dart';
import 'package:personal/features/export/data_export_launcher.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/features/home/widgets/feature_tile.dart';
import 'package:personal/features/home/widgets/home_hero_card.dart';
import 'package:personal/features/home/widgets/setup_checklist_card.dart';
import 'package:personal/features/results/results_screen.dart';
import 'package:personal/shared/navigation/fade_scale_page_route.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/content_width.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onOpenChecklist});

  /// Switches the shell to the Checklist tab.
  final VoidCallback onOpenChecklist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeTileStatsProvider);
    final healthLoading = ref.watch(homeHealthLoadingProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Grow tiles with the system font size so the stat line never clips.
    final textScaler = MediaQuery.textScalerOf(context);

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
                    HomeHeroCard(
                      onOpenChecklist: onOpenChecklist,
                      onOpenReports: () => pushFadeScaleRoute(
                        context,
                        page: const ResultsScreen(),
                      ),
                    ),
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
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 48 + textScaler.scale(86),
                ),
                itemCount: homeFeatures.length,
                itemBuilder: (context, index) {
                  final feature = homeFeatures[index];
                  return FeatureTile(
                    label: feature.label,
                    color: feature.colorFor(context),
                    icon: feature.icon,
                    stat: stats[feature.id],
                    loading:
                        healthLoading && feature.id == HomeFeatureId.health,
                    onPressed: () => pushFadeScaleRoute(
                      context,
                      page: AppRoutes.screenFor(feature.route),
                    ),
                  );
                },
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
                    Row(
                      children: [
                        Expanded(
                          child: _ToolButton(
                            icon: Icons.auto_awesome_rounded,
                            label: 'Prompt preview',
                            onPressed: () => pushFadeScaleRoute(
                              context,
                              page: AppRoutes.screenFor(
                                AppRoutes.analysisPrompt,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ToolButton(
                            icon: Icons.ios_share_rounded,
                            label: 'Export data',
                            onPressed: () => launchDataExport(context, ref),
                          ),
                        ),
                      ],
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
