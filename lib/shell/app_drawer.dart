import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/app_info.dart';
import 'package:personal/core/app_info_provider.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/core/theme/theme_mode_controller.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/calendar_service.dart';
import 'package:personal/features/calendar/calendar_settings_service.dart';
import 'package:personal/features/home/analysis_month_picker.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/features/results/analysis_service.dart';
import 'package:personal/features/results/results_screen.dart';
import 'package:personal/shared/navigation/fade_scale_page_route.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/features/settings/settings_status.dart';

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
  static const _contentPadding = EdgeInsets.symmetric(horizontal: 20);

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
                                    const SizedBox(height: 20),
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
                                    const SizedBox(height: 12),
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
                                        arguments: 'storage',
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
                                        arguments: 'ai',
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
                                    const SizedBox(height: 4),
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

class _DrawerFooter extends ConsumerWidget {
  const _DrawerFooter({required this.theme, required this.colorScheme});

  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(packageInfoProvider);
    final versionLabel = packageInfo.maybeWhen(
      data: (info) => info.version,
      orElse: () => null,
    );
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            height: 1,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppInfo.displayName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (versionLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Version $versionLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: isDarkMode ? 'Light mode' : 'Dark mode',
                onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                icon: Icon(
                  isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DrawerProfileHeader extends StatelessWidget {
  const _DrawerProfileHeader({
    required this.theme,
    required this.colorScheme,
    required this.isDark,
    required this.userTitle,
    required this.profilePhotoUrl,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;
  final bool isDark;
  final String userTitle;
  final String? profilePhotoUrl;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.16),
                  backgroundImage: profilePhotoUrl != null
                      ? NetworkImage(profilePhotoUrl!)
                      : null,
                  onBackgroundImageError: profilePhotoUrl != null
                      ? (_, _) {}
                      : null,
                  child: profilePhotoUrl == null
                      ? Icon(Icons.person, color: colorScheme.primary, size: 32)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    userTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.35 : 0.45,
            ),
            height: 1,
          ),
        ],
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _DrawerAnalysisMonthCard extends StatelessWidget {
  const _DrawerAnalysisMonthCard({
    required this.theme,
    required this.colorScheme,
    required this.monthLabel,
    required this.onTap,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;
  final String monthLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppRadii.cardLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              _DrawerIconBadge(
                icon: Icons.date_range_outlined,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analysis month',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      monthLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerNavItem extends StatelessWidget {
  const _DrawerNavItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.status,
    this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Live state line; a coloured dot marks ok / needs attention.
  final StatusLine? status;
  final Widget? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = context.palette;
    final line = status;
    final dot = switch (line?.tone) {
      StatusTone.ok => palette.accent,
      StatusTone.warning => palette.warning,
      _ => null,
    };
    final text = line?.text ?? subtitle ?? '';

    return Material(
      color: Colors.transparent,
      child: Semantics(
        button: true,
        label:
            '$title. $text'
            '${line?.tone == StatusTone.warning ? '. Needs attention' : ''}',
        excludeSemantics: true,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          visualDensity: VisualDensity.compact,
          leading: _DrawerIconBadge(icon: icon, colorScheme: colorScheme),
          title: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Row(
            children: [
              if (dot != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: line?.tone == StatusTone.warning
                      ? TextStyle(color: palette.warning)
                      : null,
                ),
              ),
            ],
          ),
          trailing:
              badge ??
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _DrawerIconBadge extends StatelessWidget {
  const _DrawerIconBadge({required this.icon, required this.colorScheme});

  final IconData icon;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: 22, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
