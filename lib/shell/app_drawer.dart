import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import '../features/calendar/calendar_service.dart';
import '../features/calendar/calendar_settings_service.dart';
import '../theme/theme_mode_controller.dart';

String _drawerUserTitle({
  required CalendarSettings? settings,
  required String? liveDisplayName,
}) {
  final savedName = settings?.connectedDisplayName?.trim();
  if (savedName != null && savedName.isNotEmpty) return savedName;

  final sessionName = liveDisplayName?.trim();
  if (sessionName != null && sessionName.isNotEmpty) return sessionName;

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
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(calendarSettingsProvider).valueOrNull;
    final calendarSummary = ref.watch(calendarSummaryProvider);
    final profilePhotoUrl =
        settings?.connectedPhotoUrl ?? calendarSummary.accountPhotoUrl;
    final userTitle = _drawerUserTitle(
      settings: settings,
      liveDisplayName: calendarSummary.accountDisplayName,
    );
    final headerGradientStart = Color.lerp(
      colorScheme.primary,
      colorScheme.tertiary,
      isDarkMode ? 0.45 : 0.35,
    )!;
    final headerGradientEnd = Color.lerp(
      colorScheme.secondaryContainer,
      colorScheme.primaryContainer,
      isDarkMode ? 0.35 : 0.55,
    )!;

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
                  children: [
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(borderRadius),
                            color: colorScheme.surface.withValues(
                              alpha: isDark ? 0.45 : 0.58,
                            ),
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
                      color: Colors.transparent,
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _DrawerProfileHeader(
                            theme: theme,
                            colorScheme: colorScheme,
                            isDark: isDark,
                            userTitle: userTitle,
                            profilePhotoUrl: profilePhotoUrl,
                            tintStart: headerGradientStart,
                            tintEnd: headerGradientEnd,
                          ),
                          _DrawerItem(
                            icon: Icons.health_and_safety_outlined,
                            title: 'Health',
                            subtitle: 'Sync & permissions',
                            onTap: () => _openRouteFromDrawer(
                              context,
                              AppRoutes.healthSettings,
                              onClose,
                            ),
                          ),
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
                            subtitle: 'Personalization profile',
                            onTap: () => _openRouteFromDrawer(
                              context,
                              AppRoutes.prompts,
                              onClose,
                            ),
                          ),
                          const Divider(indent: 16, endIndent: 16),
                          SwitchListTile(
                            tileColor: colorScheme.onSurface.withValues(
                              alpha: 0.06,
                            ),
                            secondary: const Icon(Icons.dark_mode_outlined),
                            title: const Text('Dark mode'),
                            value: isDarkMode,
                            onChanged: (enabled) => ref
                                .read(themeModeProvider.notifier)
                                .setDarkMode(enabled),
                          ),
                          _DrawerItem(
                            icon: Icons.settings_outlined,
                            title: 'General',
                            subtitle: 'Analysis month & AI settings',
                            onTap: () => _openRouteFromDrawer(
                              context,
                              AppRoutes.generalSettings,
                              onClose,
                            ),
                          ),
                        ],
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

class _DrawerProfileHeader extends StatelessWidget {
  const _DrawerProfileHeader({
    required this.theme,
    required this.colorScheme,
    required this.isDark,
    required this.userTitle,
    required this.profilePhotoUrl,
    required this.tintStart,
    required this.tintEnd,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;
  final bool isDark;
  final String userTitle;
  final String? profilePhotoUrl;
  final Color tintStart;
  final Color tintEnd;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.15, 1],
          colors: [
            tintStart.withValues(alpha: isDark ? 0.28 : 0.22),
            tintEnd.withValues(alpha: isDark ? 0.16 : 0.1),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.45),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.16),
              backgroundImage: profilePhotoUrl != null ? NetworkImage(profilePhotoUrl!) : null,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        tileColor: colorScheme.onSurface.withValues(alpha: 0.06),
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        onTap: onTap,
      ),
    );
  }
}
