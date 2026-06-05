import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import '../features/calendar/calendar_settings_service.dart';
import '../theme/theme_mode_controller.dart';

void _openRouteFromDrawer(BuildContext context, String route) {
  Navigator.pop(context);
  Navigator.pushNamed(context, route);
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  static const _borderRadius = 20.0;
  static const _outerPadding = EdgeInsets.fromLTRB(16, 16, 12, 16);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
    final isDark = theme.brightness == Brightness.dark;
    final profilePhotoUrl = ref.watch(calendarSettingsProvider).valueOrNull?.connectedPhotoUrl;
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

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      width: 320,
      child: SafeArea(
        child: Padding(
          padding: _outerPadding,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_borderRadius),
                    color: colorScheme.surface.withValues(
                      alpha: isDark ? 0.55 : 0.72,
                    ),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(
                        alpha: isDark ? 0.45 : 0.65,
                      ),
                    ),
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _DrawerProfileHeader(
                        theme: theme,
                        colorScheme: colorScheme,
                        profilePhotoUrl: profilePhotoUrl,
                        gradientStart: headerGradientStart,
                        gradientEnd: headerGradientEnd,
                      ),
                      _DrawerItem(
                        icon: Icons.health_and_safety_outlined,
                        title: 'Health',
                        subtitle: 'Sync & permissions',
                        onTap: () => _openRouteFromDrawer(context, AppRoutes.healthSettings),
                      ),
                      _DrawerItem(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Expenses',
                        subtitle: 'Cashew export folder',
                        onTap: () => _openRouteFromDrawer(context, AppRoutes.expensesSettings),
                      ),
                      _DrawerItem(
                        icon: Icons.route_outlined,
                        title: 'Location',
                        subtitle: 'Timeline folder',
                        onTap: () => _openRouteFromDrawer(context, AppRoutes.locationSettings),
                      ),
                      _DrawerItem(
                        icon: Icons.sports_esports_outlined,
                        title: 'Game Activity',
                        subtitle: 'Export folder',
                        onTap: () => _openRouteFromDrawer(context, AppRoutes.gameActivitySettings),
                      ),
                      _DrawerItem(
                        icon: Icons.calendar_month_outlined,
                        title: 'Calendar',
                        subtitle: 'Google account sync',
                        onTap: () => _openRouteFromDrawer(context, AppRoutes.calendarSettings),
                      ),
                      _DrawerItem(
                        icon: Icons.tune_outlined,
                        title: 'System Prompt',
                        subtitle: 'Personalization profile',
                        onTap: () => _openRouteFromDrawer(context, AppRoutes.prompts),
                      ),
                      const Divider(indent: 16, endIndent: 16),
                      SwitchListTile(
                        secondary: const Icon(Icons.dark_mode_outlined),
                        title: const Text('Dark mode'),
                        value: isDarkMode,
                        onChanged: (enabled) => ref.read(themeModeProvider.notifier).setDarkMode(enabled),
                      ),
                      _DrawerItem(
                        icon: Icons.settings_outlined,
                        title: 'General',
                        subtitle: 'Analysis month & AI settings',
                        onTap: () => _openRouteFromDrawer(context, AppRoutes.generalSettings),
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

class _DrawerProfileHeader extends StatelessWidget {
  const _DrawerProfileHeader({
    required this.theme,
    required this.colorScheme,
    required this.profilePhotoUrl,
    required this.gradientStart,
    required this.gradientEnd,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;
  final String? profilePhotoUrl;
  final Color gradientStart;
  final Color gradientEnd;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.15, 1],
          colors: [gradientStart, gradientEnd],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.2),
              backgroundImage: profilePhotoUrl != null ? NetworkImage(profilePhotoUrl!) : null,
              onBackgroundImageError: profilePhotoUrl != null ? (_, _) {} : null,
              child: profilePhotoUrl == null ? Icon(Icons.person, color: colorScheme.onPrimary, size: 32) : null,
            ),
            const SizedBox(height: 12),
            Text(
              'Personal',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Settings & preferences',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimary.withValues(alpha: 0.85),
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
    return ListTile(leading: Icon(icon), title: Text(title), subtitle: subtitle != null ? Text(subtitle!) : null, onTap: onTap);
  }
}
