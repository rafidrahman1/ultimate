import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/export/data_export_launcher.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/features/home/widgets/feature_tile.dart';
import 'package:personal/shared/navigation/fade_scale_page_route.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeTileStatsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const extraBottomForNavPill = 90.0;
    // Grow tiles with the system font size so the stat line never clips.
    final textScaler = MediaQuery.textScalerOf(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            0,
          ),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 56 + textScaler.scale(56),
            ),
            itemCount: homeFeatures.length,
            itemBuilder: (context, index) {
              final feature = homeFeatures[index];
              return FeatureTile(
                label: feature.label,
                color: feature.colorFor(context),
                icon: feature.icon,
                stat: stats[feature.id],
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
            bottomInset + extraBottomForNavPill,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tools',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _ToolButton(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Prompt preview',
                        onPressed: () => pushFadeScaleRoute(
                          context,
                          page: AppRoutes.screenFor(AppRoutes.analysisPrompt),
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
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        backgroundColor: colorScheme.surface,
        side: BorderSide(color: colorScheme.outline),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
        ),
      ),
    );
  }
}
