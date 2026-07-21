import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/app_info.dart';
import 'package:personal/core/app_info_provider.dart';
import 'package:personal/core/theme/theme_mode_controller.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/calendar_service.dart';
import 'package:personal/features/calendar/calendar_settings_service.dart';
import 'package:personal/features/settings/widgets/month_picker_dialog.dart';

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
  VoidCallback onClose,
) {
  onClose();
  Navigator.pushNamed(context, route);
}

Future<void> _pickAnalysisMonth(
  BuildContext context,
  WidgetRef ref,
  DateTime currentMonth,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await showMonthPicker(
    context: context,
    initialDate: currentMonth,
    firstDate: DateTime(2020, 1),
    lastDate: DateTime(DateTime.now().year + 1, 12),
    helpText: 'Choose analysis month',
  );
  if (picked == null || !context.mounted) return;
  await ref.read(selectedAnalysisMonthProvider.notifier).setMonth(picked);
  if (!context.mounted) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        'Analysis month set to ${DateFormat('MMMM yyyy').format(picked)}',
      ),
    ),
  );
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
    final drawerSurfaceColor = colorScheme.surface.withValues(
      alpha: isDark ? 0.55 : 0.72,
    );
    final analysisMonth = ref.watch(selectedAnalysisMonthProvider);
    final monthLabel = DateFormat('MMMM yyyy').format(analysisMonth);

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
                            borderRadius: BorderRadius.circular(borderRadius),
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
                                padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                                children: [
                                  Padding(
                                    padding: _contentPadding,
                                    child: _DrawerAnalysisMonthCard(
                                      theme: theme,
                                      colorScheme: colorScheme,
                                      monthLabel: monthLabel,
                                      onTap: () => _pickAnalysisMonth(
                                        context,
                                        ref,
                                        analysisMonth,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const _DrawerSectionLabel('Settings'),
                                  _DrawerNavItem(
                                    icon: Icons.sync_outlined,
                                    title: 'Google Account',
                                    subtitle: 'Calendar and profile backup',
                                    onTap: () => _openRouteFromDrawer(
                                      context,
                                      AppRoutes.calendarSettings,
                                      onClose,
                                    ),
                                  ),
                                  _DrawerNavItem(
                                    icon: Icons.settings_outlined,
                                    title: 'General',
                                    subtitle: 'Data folder and notifications',
                                    onTap: () => _openRouteFromDrawer(
                                      context,
                                      AppRoutes.generalSettings,
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
      borderRadius: BorderRadius.circular(14),
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
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
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
        subtitle: Text(subtitle),
        trailing: Icon(
          Icons.chevron_right,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        onTap: onTap,
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: 22, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
