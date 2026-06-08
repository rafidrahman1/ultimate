import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import '../core/app_info.dart';
import '../core/app_info_provider.dart';
import '../theme/theme_mode_controller.dart';
import '../widgets/circular_app_bar_button.dart';
import '../features/auth/google_account_service.dart';
import '../features/calendar/calendar_service.dart';
import '../features/calendar/calendar_settings_service.dart';

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

void _openRouteFromDrawer(BuildContext context, String route, VoidCallback onClose) {
  onClose();
  Navigator.pushNamed(context, route);
}

class AppDrawerPanel extends ConsumerWidget {
  const AppDrawerPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  static const borderRadius = 20.0;
  static const width = 320.0;
  static const outerPadding = EdgeInsets.fromLTRB(16, 16, 12, 16);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(calendarSettingsProvider).valueOrNull;
    final calendarSummary = ref.watch(calendarSummaryProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final profilePhotoUrl = settings?.connectedPhotoUrl ??
        calendarSummary.accountPhotoUrl ??
        authUser?.photoURL;
    final userTitle = _drawerUserTitle(
      settings: settings,
      liveDisplayName: calendarSummary.accountDisplayName,
      firebaseDisplayName: authUser?.displayName,
      firebaseEmail: authUser?.email,
    );
    final drawerSurfaceColor = colorScheme.surface.withValues(
      alpha: isDark ? 0.55 : 0.72,
    );
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Material(
      type: MaterialType.transparency,
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
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
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
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(borderRadius),
                            color: drawerSurfaceColor,
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: isDark ? 0.45 : 0.65,
                              ),
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
                                padding: EdgeInsets.zero,
                                children: [
                          _DrawerItem(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Expenses',
                            subtitle: 'Cashew export folder',
                            onTap: () => _openRouteFromDrawer(
                              context,
                              AppRoutes.expensesSettings,
                              onClose,
                            ),
                          ),
                          _DrawerItem(
                            icon: Icons.route_outlined,
                            title: 'Location',
                            subtitle: 'Timeline folder',
                            onTap: () => _openRouteFromDrawer(
                              context,
                              AppRoutes.locationSettings,
                              onClose,
                            ),
                          ),
                          _DrawerItem(
                            icon: Icons.sports_esports_outlined,
                            title: 'Game Activity',
                            subtitle: 'Export folder',
                            onTap: () => _openRouteFromDrawer(
                              context,
                              AppRoutes.gameActivitySettings,
                              onClose,
                            ),
                          ),
                          _DrawerItem(
                            icon: Icons.calendar_month_outlined,
                            title: 'Calendar',
                            subtitle: 'Google account sync',
                            onTap: () => _openRouteFromDrawer(
                              context,
                              AppRoutes.calendarSettings,
                              onClose,
                            ),
                          ),
                          _DrawerItem(
                            icon: Icons.tune_outlined,
                            title: 'System Prompt',
                            subtitle: 'Personal profile and assistant tone',
                            onTap: () => _openRouteFromDrawer(
                              context,
                              AppRoutes.prompts,
                              onClose,
                            ),
                          ),
                          _DrawerItem(
                            icon: Icons.insights_outlined,
                            title: 'Results',
                            subtitle: 'Report save folder',
                            onTap: () => _openRouteFromDrawer(
                              context,
                              AppRoutes.resultsSettings,
                              onClose,
                            ),
                          ),
                          _DrawerItem(
                            icon: Icons.settings_outlined,
                            title: 'General',
                            subtitle: 'Analysis month, Health & AI',
                            onTap: () => _openRouteFromDrawer(
                              context,
                              AppRoutes.generalSettings,
                              onClose,
                            ),
                          ),
                                ],
                              ),
                            ),
                            _DrawerFooter(theme: theme, colorScheme: colorScheme),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: CircularAppBarButton(
                        icon: isDarkMode
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        onPressed: () =>
                            ref.read(themeModeProvider.notifier).toggle(),
                      ),
                    ),
                  ],
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            height: 1,
          ),
          const SizedBox(height: 12),
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
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.16),
                  backgroundImage:
                      profilePhotoUrl != null ? NetworkImage(profilePhotoUrl!) : null,
                  onBackgroundImageError: profilePhotoUrl != null ? (_, _) {} : null,
                  child: profilePhotoUrl == null
                      ? Icon(Icons.person, color: colorScheme.primary, size: 32)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
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
              ],
            ),
          ),
          Divider(
            color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.45),
            height: 1,
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.title, this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        onTap: onTap,
      ),
    );
  }
}
