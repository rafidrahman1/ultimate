import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal/app/router.dart';
import 'package:personal/core/error_display.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/ui/dashboard_tiles.dart';
import 'package:personal/features/dashboard/view/dashboard_layout_service.dart';
import 'package:personal/features/dashboard/view/dashboard_provider.dart';
import 'package:personal/features/dashboard/view/dashboard_view_data.dart';
import 'package:personal/features/home/home_refresh.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';
import 'package:personal/shared/widgets/status_message.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(dashboardViewProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return dataAsync.when(
      loading: () => CardListSkeleton(bottomPadding: bottomInset + AppLayout.navPillClearance),
      error: (error, _) => StatusMessage(
        icon: Icons.error_outline,
        title: 'Could not build dashboard',
        subtitle: humanizeError(error),
        action: OutlinedButton(onPressed: () => ref.invalidate(dashboardViewProvider), child: const Text('Try again')),
      ),
      data: (data) => data.hasAnyData
          ? _DashboardBody(data: data, bottomInset: bottomInset)
          : StatusMessage(
              icon: Icons.dashboard_outlined,
              title: 'No data yet',
              subtitle:
                  'Import health, expenses, location, gaming, or calendar '
                  'data from Home for ${data.periodLabel}.',
            ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data, required this.bottomInset});

  final DashboardViewData data;
  final double bottomInset;

  /// Each tile opens the page that holds that source's full detail.
  static String _routeFor(DashboardCardId id) => switch (id) {
    DashboardCardId.health || DashboardCardId.stableMonth => AppRoutes.healthData,
    DashboardCardId.financial => AppRoutes.expenses,
    DashboardCardId.mobility => AppRoutes.location,
    DashboardCardId.gaming => AppRoutes.gameActivity,
    DashboardCardId.calendar => AppRoutes.calendar,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContentWidth(
      child: RefreshIndicator(
        onRefresh: () => refreshAllSources(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, bottomInset + AppLayout.navPillClearance),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [DashboardTileBoard(data: data, onOpenCard: (id) => Navigator.pushNamed(context, _routeFor(id)))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
