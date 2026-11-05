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
import 'package:personal/features/settings/ai_settings_service.dart';
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

void _openRouteFromDrawer(
  BuildContext context,
  String route,
  VoidCallback onClose, {
  Object? arguments,
}) {
  onClose();
  Navigator.pushNamed(context, route, arguments: arguments);
}

/// Provider name when AI requests are actually enabled and keyed, else null.
String? _activeAiProviderLabel(AiSettings? ai) {
  if (ai == null || !ai.enableApiCalls) return null;
  final key = switch (ai.provider) {
    AiProvider.openai => ai.openAiApiKey,
    AiProvider.gemini => ai.geminiApiKey,
    AiProvider.anthropic => ai.anthropicApiKey,
  };
  return key.trim().isEmpty ? null : ai.provider.label;
}

class AppDrawerPanel extends ConsumerWidget {
  const AppDrawerPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  static const borderRadius = 28.0;
  static const maxWidth = 400.0;
  static const outerPadding = EdgeInsets.fromLTRB(12, 12, 8, 12);

  /// About 88% of the screen, so a sliver of the page stays visible.
  static double widthFor(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.88).clamp(280.0, maxWidth);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
    final chrome = context.surfaceChrome;
    final analysisMonth = ref.watch(selectedAnalysisMonthProvider);
    final now = DateTime.now();
    final isCurrentMonth =
        analysisMonth.year == now.year && analysisMonth.month == now.month;
    final status = ref.watch(settingsStatusProvider);
    final aiProvider = _activeAiProviderLabel(
      ref.watch(aiSettingsProvider).valueOrNull,
    );
    final googleConnected =
        (settings?.isConnected ?? false) || authUser != null;
    const rowPadding = EdgeInsets.symmetric(horizontal: AppSpacing.sm);

    void open(String route, {Object? arguments}) =>
        _openRouteFromDrawer(context, route, onClose, arguments: arguments);

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
                          _DrawerProfileHeader(
                            userTitle: userTitle,
                            profilePhotoUrl: profilePhotoUrl,
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.md,
                                    AppSpacing.lg,
                                    0,
                                  ),
                                  child: _DrawerAnalysisMonthCard(
                                    monthLabel: DateFormat(
                                      'MMMM yyyy',
                                    ).format(analysisMonth),
                                    isCurrentMonth: isCurrentMonth,
                                    onTap: () =>
                                        pickAnalysisMonth(context, ref),
                                  ),
                                ),
                                _DrawerSetupProgress(status: status),
                                const _DrawerSectionLabel('SETUP & DATA'),
                                Padding(
                                  padding: rowPadding,
                                  child: Column(
                                    children: [
                                      _DrawerNavItem(
                                        icon: Icons.folder_outlined,
                                        title: 'Storage & backup',
                                        status: status.storage,
                                        onTap: () => open(
                                          AppRoutes.generalSettings,
                                          arguments: SettingsSection.storage,
                                        ),
                                      ),
                                      _DrawerNavItem(
                                        icon: Icons.auto_awesome_outlined,
                                        title: 'AI provider',
                                        status: status.ai,
                                        onTap: () => open(
                                          AppRoutes.generalSettings,
                                          arguments: SettingsSection.ai,
                                        ),
                                      ),
                                      _DrawerNavItem(
                                        icon: Icons.person_outline,
                                        title: 'Personal information',
                                        status: status.profile,
                                        onTap: () =>
                                            open(AppRoutes.personalInformation),
                                      ),
                                      _DrawerNavItem(
                                        icon: Icons.account_circle_outlined,
                                        title: 'Google account',
                                        status: status.account,
                                        onTap: () =>
                                            open(AppRoutes.calendarSettings),
                                      ),
                                    ],
                                  ),
                                ),
                                const _DrawerSectionLabel('APP'),
                                Padding(
                                  padding: rowPadding,
                                  child: _DrawerNavItem(
                                    icon: Icons.settings_outlined,
                                    title: 'All settings',
                                    subtitle: 'Search every option',
                                    onTap: () => open(AppRoutes.settings),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.lg,
                                    AppSpacing.lg,
                                    0,
                                  ),
                                  child: _DrawerPrivacyCard(
                                    aiProviderLabel: aiProvider,
                                    googleConnected: googleConnected,
                                    onTap: () => open(
                                      AppRoutes.generalSettings,
                                      arguments: SettingsSection.ai,
                                    ),
                                  ),
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
