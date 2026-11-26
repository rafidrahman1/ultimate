import 'dart:ui';

import 'package:clock/clock.dart';
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
import 'package:personal/features/settings/settings_status.dart';

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

/// The side menu: who is signed in, the month being looked at, every data
/// screen, and Settings. Everything else lives behind Settings.
class AppDrawerPanel extends ConsumerWidget {
  const AppDrawerPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  static const borderRadius = 28.0;
  static const maxWidth = 360.0;
  static const outerPadding = EdgeInsets.fromLTRB(12, 12, 8, 12);

  /// About 80% of the screen, so a sliver of the page stays visible.
  static double widthFor(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.8).clamp(272.0, maxWidth);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(calendarSettingsProvider).value;
    final calendarSummary = ref.watch(calendarSummaryProvider);
    final authUser = ref.watch(authStateProvider).value;
    final photoUrl =
        settings?.connectedPhotoUrl ??
        calendarSummary.accountPhotoUrl ??
        authUser?.photoURL;
    final userTitle = _drawerUserTitle(
      settings: settings,
      liveDisplayName: calendarSummary.accountDisplayName,
      firebaseDisplayName: authUser?.displayName,
      firebaseEmail: authUser?.email,
    );
    final chrome = context.surfaceChrome;
    final month = ref.watch(selectedAnalysisMonthProvider);
    final now = clock.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    final toFix = ref.watch(settingsStatusProvider).warningCount;

    void open(String route) {
      onClose();
      Navigator.pushNamed(context, route);
    }

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -300) onClose();
        },
        child: SizedBox(
          width: widthFor(context),
          child: SafeArea(
            child: Padding(
              padding: outerPadding,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(
                        alpha: isDark ? 0.4 : 0.14,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(borderRadius),
                        color: chrome.translucentSurface,
                        border: Border.all(color: chrome.translucentBorder),
                      ),
                      child: Column(
                        children: [
                          _DrawerHeader(
                            userTitle: userTitle,
                            photoUrl: photoUrl,
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.sm,
                                AppSpacing.sm,
                                AppSpacing.sm,
                                AppSpacing.md,
                              ),
                              children: [
                                _DrawerRow(
                                  icon: Icons.calendar_month_outlined,
                                  color: palette.textSecondary,
                                  title: DateFormat('MMMM yyyy').format(month),
                                  trailing: Text(
                                    isCurrentMonth ? 'This month' : 'Change',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(color: palette.textMuted),
                                  ),
                                  semanticsLabel:
                                      'Showing ${DateFormat('MMMM yyyy').format(month)}. '
                                      'Change month',
                                  onTap: () => pickAnalysisMonth(context, ref),
                                ),
                                const _DrawerDivider(),
                                for (final f in homeFeatures)
                                  _DrawerRow(
                                    icon: f.icon,
                                    color: f.colorFor(context),
                                    title: f.label,
                                    onTap: () => open(f.route),
                                  ),
                                _DrawerRow(
                                  icon: Icons.mood_rounded,
                                  color: palette.textSecondary,
                                  title: 'Journal',
                                  onTap: () => open(AppRoutes.journal),
                                ),
                                const _DrawerDivider(),
                                _DrawerRow(
                                  icon: Icons.settings_outlined,
                                  color: palette.textSecondary,
                                  title: 'Settings',
                                  trailing: toFix > 0
                                      ? _AttentionDot(count: toFix)
                                      : null,
                                  semanticsLabel: toFix > 0
                                      ? 'Settings. $toFix need attention'
                                      : 'Settings',
                                  onTap: () => open(AppRoutes.settings),
                                ),
                              ],
                            ),
                          ),
                          const _DrawerFooter(),
                        ],
                      ),
                    ),
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
