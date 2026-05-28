import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
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

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colorScheme.primary, colorScheme.primaryContainer],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.2),
                  child: Icon(
                    Icons.person,
                    color: colorScheme.onPrimary,
                    size: 32,
                  ),
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
          _DrawerItem(
            icon: Icons.health_and_safety_outlined,
            title: 'Health',
            subtitle: 'Sync & permissions',
            onTap: () =>
                _openRouteFromDrawer(context, AppRoutes.healthSettings),
          ),
          _DrawerItem(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Expenses',
            subtitle: 'Cashew export folder',
            onTap: () =>
                _openRouteFromDrawer(context, AppRoutes.expensesSettings),
          ),
          _DrawerItem(
            icon: Icons.route_outlined,
            title: 'Location',
            subtitle: 'Timeline folder',
            onTap: () =>
                _openRouteFromDrawer(context, AppRoutes.locationSettings),
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
            onChanged: (enabled) =>
                ref.read(themeModeProvider.notifier).setDarkMode(enabled),
          ),
          _DrawerItem(
            icon: Icons.settings_outlined,
            title: 'General',
            subtitle: 'AI provider & API keys',
            onTap: () =>
                _openRouteFromDrawer(context, AppRoutes.generalSettings),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      onTap: onTap,
    );
  }
}
