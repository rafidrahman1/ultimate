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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
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
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.15, 1],
                colors: [headerGradientStart, headerGradientEnd],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.2),
                  backgroundImage: profilePhotoUrl != null ? NetworkImage(profilePhotoUrl) : null,
                  onBackgroundImageError: (_, __) {},
                  child: profilePhotoUrl == null ? Icon(Icons.person, color: colorScheme.onPrimary, size: 32) : null,
                ),
                const SizedBox(height: 12),
                Text(
                  'Personal',
                  style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
                ),
                Text('Settings & preferences', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onPrimary.withValues(alpha: 0.85))),
              ],
            ),
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
          _DrawerItem(icon: Icons.route_outlined, title: 'Location', subtitle: 'Timeline folder', onTap: () => _openRouteFromDrawer(context, AppRoutes.locationSettings)),
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
          _DrawerItem(icon: Icons.tune_outlined, title: 'System Prompt', subtitle: 'Personalization profile', onTap: () => _openRouteFromDrawer(context, AppRoutes.prompts)),
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
