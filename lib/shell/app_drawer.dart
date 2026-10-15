import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal/app/router.dart';
import 'package:personal/core/app_info/app_info.dart';
import 'package:personal/core/app_info/app_info_provider.dart';
import 'package:personal/core/period/analysis_month_settings_service.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/core/theme/theme_mode_controller.dart';
import 'package:personal/features/analysis/ui/analysis_month_picker.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/data/calendar_service.dart';
import 'package:personal/features/calendar/data/calendar_settings_service.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/features/results/pipeline/analysis_service.dart';
import 'package:personal/features/results/reports/results_service.dart';
import 'package:personal/features/results/ui/results_screen.dart';
import 'package:personal/features/settings/settings_status.dart';
import 'package:personal/shared/navigation/fade_scale_page_route.dart';

part 'app_drawer_chrome.dart';
part 'app_drawer_items.dart';

String _drawerUserTitle({
  required CalendarSettings? settings,
  required String? liveDisplayName,
  required String? firebaseDisplayName,
  required String? firebaseEmail,
}) {
  final savedName = settings?.connectedDisplayName?.trim();
  if (savedName != null && savedName.isNotEmpty) return savedName;

  final sessionName = liveDisplayName?.trim();
  if (sessionName != null && sessionName.isNotEmpty) return sessionName;

  final authName = firebaseDisplayName?.trim();
  if (authName != null && authName.isNotEmpty) return authName;

  final authEmail = firebaseEmail?.trim();
  if (authEmail != null && authEmail.isNotEmpty) return authEmail;

  return 'Personal';
}

void _openRouteFromDrawer(
  BuildContext context,
  String route,
  VoidCallback onClose, {
  Object? arguments,
}) {
  onClose();
  if (route == ReportsRoute.path) {
    pushFadeScaleRoute(context, page: const ResultsScreen());
    return;
  }
  Navigator.pushNamed(context, route, arguments: arguments);
}

/// Pseudo-route so the drawer can open Reports like any other destination.
abstract final class ReportsRoute {
  static const path = '/reports';
}

class AppDrawerPanel extends ConsumerWidget {
  const AppDrawerPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  static const borderRadius = 20.0;
  static const width = 320.0;
  static const outerPadding = EdgeInsets.fromLTRB(16, 16, 12, 16);
  static const _contentPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.xl,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(calendarSettingsProvider).valueOrNull;
    final calendarSummary = ref.watch(calendarSummaryProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final profilePhotoUrl =
        settings?.connectedPhotoUrl ??
        calendarSummary.accountPhotoUrl ??
        authUser?.photoURL;
    final userTitle = _drawerUserTitle(
      settings: settings,
      liveDisplayName: calendarSummary.accountDisplayName,
      firebaseDisplayName: authUser?.displayName,
      firebaseEmail: authUser?.email,
    );
    final surfaceChrome = context.surfaceChrome;
    final drawerSurfaceColor = surfaceChrome.translucentSurface;
    final analysisMonth = ref.watch(selectedAnalysisMonthProvider);
    final monthLabel = DateFormat('MMMM yyyy').format(analysisMonth);
    final status = ref.watch(settingsStatusProvider);
    final isRunning = ref.watch(
      analysisRunProvider.select((state) => state.isRunning),
    );
    final reportCount = ref.watch(analysisResultsProvider).valueOrNull?.length;
    final dashboardStat = ref.watch(
      homeTileStatsProvider.select((stats) => stats[HomeFeatureId.dashboard]),
    );

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -300) onClose();
        },
        child: SizedBox(
          width: width,
          child: SafeArea(
            child: Padding(
              padding: outerPadding,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(
                        alpha: isDark ? 0.35 : 0.12,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(borderRadius),
                              color: drawerSurfaceColor,
                              border: Border.all(
                                color: surfaceChrome.translucentBorder,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Material(
                        color: drawerSurfaceColor,
                        child: Theme(
                          data: theme.copyWith(
                            listTileTheme: theme.listTileTheme.copyWith(
                              shape: const RoundedRectangleBorder(),
                            ),
                          ),
                          child: Column(
                            children: [
                              _DrawerProfileHeader(
                                theme: theme,
                                colorScheme: colorScheme,
                                isDark: isDark,
                                userTitle: userTitle,
                                profilePhotoUrl: profilePhotoUrl,
                              ),
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    12,
                                    0,
                                    8,
                                  ),
                                  children: [
                                    Padding(
                                      padding: _contentPadding,
                                      child: _DrawerAnalysisMonthCard(
                                        theme: theme,
                                        colorScheme: colorScheme,
                                        monthLabel: monthLabel,
                                        onTap: () =>
                                            pickAnalysisMonth(context, ref),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xl),
                                    const _DrawerSectionLabel('Explore'),
                                    _DrawerNavItem(
                                      icon: Icons.space_dashboard_outlined,
                                      title: 'Dashboard',
                                      subtitle: dashboardStat == null
                                          ? 'Load data to see trends'
                                          : '${dashboardStat.value} ${dashboardStat.caption}',
                                      onTap: () => _openRouteFromDrawer(
                                        context,
                                        AppRoutes.dashboard,
                                        onClose,
                                      ),
                                    ),
                                    _DrawerNavItem(
                                      icon: Icons.insights_outlined,
                                      title: 'Reports',
                                      subtitle: isRunning
                                          ? 'Analysis running…'
                                          : reportCount == null
                                          ? 'Saved analyses'
                                          : '$reportCount saved',
                                      badge: isRunning
                                          ? const SizedBox.square(
                                              dimension: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : null,
                                      onTap: () => _openRouteFromDrawer(
                                        context,
                                        ReportsRoute.path,
                                        onClose,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    _DrawerSectionLabel(
                                      status.warningCount == 0
                                          ? 'Setup · all set'
                                          : 'Setup · ${status.warningCount} to fix',
                                    ),
                                    _DrawerNavItem(
                                      icon: Icons.folder_outlined,
                                      title: 'Storage & backup',
                                      status: status.storage,
                                      onTap: () => _openRouteFromDrawer(
                                        context,
                                        AppRoutes.generalSettings,
                                        onClose,
                                        arguments: SettingsSection.storage,
                                      ),
                                    ),
                                    _DrawerNavItem(
                                      icon: Icons.auto_awesome_outlined,
                                      title: 'AI provider',
                                      status: status.ai,
                                      onTap: () => _openRouteFromDrawer(
                                        context,
                                        AppRoutes.generalSettings,
                                        onClose,
                                        arguments: SettingsSection.ai,
                                      ),
                                    ),
                                    _DrawerNavItem(
                                      icon: Icons.person_outline,
                                      title: 'Personal information',
                                      status: status.profile,
                                      onTap: () => _openRouteFromDrawer(
                                        context,
                                        AppRoutes.personalInformation,
                                        onClose,
                                      ),
                                    ),
                                    _DrawerNavItem(
                                      icon: Icons.account_circle_outlined,
                                      title: 'Google account',
                                      status: status.account,
                                      onTap: () => _openRouteFromDrawer(
                                        context,
                                        AppRoutes.calendarSettings,
                                        onClose,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    _DrawerNavItem(
                                      icon: Icons.settings_outlined,
                                      title: 'All settings',
                                      subtitle: 'Search every option',
                                      onTap: () => _openRouteFromDrawer(
                                        context,
                                        AppRoutes.settings,
                                        onClose,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _DrawerFooter(
                                theme: theme,
                                colorScheme: colorScheme,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
