import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal/app/router.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/ui/dashboard_screen.dart';
import 'package:personal/features/export/data_export_launcher.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_refresh.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/features/home/widgets/monthly_overview_card.dart';
import 'package:personal/features/home/widgets/setup_checklist_card.dart';
import 'package:personal/features/journal/data/journal_models.dart';
import 'package:personal/features/journal/data/journal_service.dart';
import 'package:personal/features/journal/ui/check_in_card.dart';
import 'package:personal/shared/navigation/fade_scale_page_route.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/content_width.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
                    const _EveningCheckIn(),
                    const MonthlyOverviewCard(),
                    const DashboardSection(),
                    const _AddDataChips(),
                  ],
                ),
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
                      icon: Icons.mood_rounded,
                      label: 'Check-in, coffee & meals',
                      onPressed: () => pushFadeScaleRoute(
                        context,
                        page: AppRoutes.screenFor(AppRoutes.journal),
                      ),
                    ),
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

/// Today's check-in, offered from the evening until it is filled in.
class _EveningCheckIn extends ConsumerStatefulWidget {
  const _EveningCheckIn();

  @override
  ConsumerState<_EveningCheckIn> createState() => _EveningCheckInState();
}

class _EveningCheckInState extends ConsumerState<_EveningCheckIn> {
  static const _fromHour = 17;

  // Once shown it stays for this visit, so the card does not vanish under
  // the finger on the third tap.
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final now = clock.now();
    final evening = now.hour >= _fromHour || now.hour < habitDayStartHour;
    final logged =
        ref.watch(journalProvider).checkInOn(habitDayOf(now)) != null;
    if (evening && !logged) _shown = true;
    if (!_shown) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg),
      child: CheckInCard(),
    );
  }
}

/// Sources with nothing for the month: one tap to set up or import. Sources
/// that have data are already shown as tiles by [DashboardSection].
class _AddDataChips extends ConsumerWidget {
  const _AddDataChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeTileStatsProvider);
    final healthLoading = ref.watch(homeHealthLoadingProvider);
    final empty = [
      for (final f in homeFeatures)
        if (stats[f.id] == null &&
            !(healthLoading && f.id == HomeFeatureId.health))
          f,
    ];
    if (empty.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ADD DATA', style: context.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final f in empty)
                Semantics(
                  button: true,
                  label: 'Set up ${f.label}',
                  excludeSemantics: true,
                  child: Material(
                    color: palette.card,
                    shape: StadiumBorder(
                      side: BorderSide(color: palette.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => pushFadeScaleRoute(
                        context,
                        page: AppRoutes.screenFor(f.route),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(f.icon, size: 16, color: f.colorFor(context)),
                            const SizedBox(width: 6),
                            Text(
                              f.label,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: palette.textSecondary),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: palette.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
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
