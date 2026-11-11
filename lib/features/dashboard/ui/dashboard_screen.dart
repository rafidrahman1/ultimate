import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal/app/router.dart';
import 'package:personal/core/error_display.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/ui/dashboard_tiles.dart';
import 'package:personal/features/dashboard/view/dashboard_layout_service.dart';
import 'package:personal/features/dashboard/view/dashboard_provider.dart';
import 'package:personal/features/dashboard/view/dashboard_view_data.dart';

/// The dashboard tile board, embedded in Home below the monthly overview.
/// Renders nothing while loading or when the month has no data (Home's
/// overview and source cards already cover those states).
class DashboardSection extends ConsumerWidget {
  const DashboardSection({super.key});

  /// Each tile opens the page that holds that source's full detail.
  static String _routeFor(DashboardCardId id) => switch (id) {
    DashboardCardId.health ||
    DashboardCardId.stableMonth => AppRoutes.healthData,
    DashboardCardId.financial => AppRoutes.expenses,
    DashboardCardId.mobility => AppRoutes.location,
    DashboardCardId.gaming => AppRoutes.gameActivity,
    DashboardCardId.calendar => AppRoutes.calendar,
    DashboardCardId.screenTime => AppRoutes.screenTime,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(dashboardViewProvider);
    // Until the live board is computed, show the last saved one.
    final cached = ref.watch(dashboardCachedProvider).value;
    if (dataAsync.value == null && cached != null && !dataAsync.hasError) {
      return _board(context, cached);
    }
    return dataAsync.when(
      // Source refreshes rebuild the provider; keep the last tiles on screen.
      skipLoadingOnReload: true,
      loading: () => const SizedBox.shrink(),
      error: (error, _) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Could not build dashboard: ${humanizeError(error)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(dashboardViewProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) => _board(context, data),
    );
  }

  Widget _board(BuildContext context, DashboardViewData data) => data.hasAnyData
      ? Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: DashboardTileBoard(
            data: data,
            onOpenCard: (id) => Navigator.pushNamed(context, _routeFor(id)),
          ),
        )
      : const SizedBox.shrink();
}
