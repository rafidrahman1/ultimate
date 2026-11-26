import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/error_display.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/data/calendar_service.dart';
import 'package:personal/features/calendar/data/calendar_settings_service.dart';
import 'package:personal/features/settings/widgets/backup_section.dart';
import 'package:personal/features/settings/widgets/drive_files_card.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/settings_kit.dart';
import 'package:personal/shared/widgets/status_message.dart';

class CalendarSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSettingsScreen> createState() =>
      _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState
    extends ConsumerState<CalendarSettingsScreen> {
  bool _connecting = false;
  Object? _signInError;

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _signInError = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(calendarSummaryProvider.notifier).connectAndSync();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Google account connected — calendar sync and profile backup enabled',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _signInError = e);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disconnect Google account?'),
        content: const Text(
          'Calendar sync and profile backup stop. Data already on this '
          'device stays.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(calendarSummaryProvider.notifier).signOut();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Google account disconnected — calendar sync and profile backup disabled',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(calendarSettingsProvider);
    final authUser = ref.watch(authStateProvider).value;
    final summary = ref.watch(calendarSummaryProvider);
    final palette = context.palette;

    return Scaffold(
      appBar: AppScreenAppBar.build(context, ref, title: 'Google account'),
      body: settingsAsync.when(
        data: (settings) {
          final isConnected = settings.isConnected || authUser != null;
          final email = settings.isConnected
              ? settings.connectedEmail
              : authUser?.email;
          final name = settings.connectedDisplayName?.trim().isNotEmpty == true
              ? settings.connectedDisplayName!
              : authUser?.displayName;
          final photo =
              settings.connectedPhotoUrl ??
              summary.accountPhotoUrl ??
              authUser?.photoURL;

          final status = context.statusColors;
          return ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                AppSpacing.xxl,
              ),
              children: [
                SettingsPageHeader(
                  icon: Icons.account_circle_outlined,
                  title: isConnected
                      ? (name ?? 'Google account')
                      : 'Google account',
                  status: isConnected
                      ? (email?.isNotEmpty == true ? email! : 'Connected')
                      : 'Not signed in · everything stays local',
                  statusColor: isConnected ? status.good : null,
                  description:
                      'Signing in adds calendar events, syncs your profile '
                      'and lets the app read and save its files on Drive.',
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: palette.accent.withValues(
                      alpha: AppOpacity.medium,
                    ),
                    backgroundImage: photo != null
                        ? ResizeImage(NetworkImage(photo), width: 144)
                        : null,
                    onBackgroundImageError: photo != null ? (_, _) {} : null,
                    child: photo == null
                        ? Icon(
                            Icons.account_circle_outlined,
                            color: palette.accent,
                          )
                        : null,
                  ),
                  actions: [
                    if (isConnected)
                      TextButton.icon(
                        onPressed: _connecting ? null : _disconnect,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Disconnect'),
                      ),
                    FilledButton.icon(
                      onPressed: _connecting ? null : _connect,
                      icon: _connecting
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login, size: 18),
                      label: Text(
                        _connecting
                            ? 'Signing in…'
                            : isConnected
                            ? 'Sign in again'
                            : 'Sign in with Google',
                      ),
                    ),
                  ],
                ),
                if (_signInError != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _SignInErrorCard(error: _signInError!),
                ],
                const SettingsGroup(
                  label: 'What it syncs',
                  children: [
                    SettingsTile(
                      icon: Icons.calendar_month_outlined,
                      title: 'Calendar events',
                      subtitle:
                          'Read-only, including Bangladesh public holidays. '
                          'Predictions are added only if you turn that on '
                          'in Notifications.',
                    ),
                    SettingsTile(
                      icon: Icons.person_outline,
                      title: 'Personal information',
                      subtitle:
                          'Only your profile syncs, scoped to your account, '
                          'so a new phone can pick it up.',
                    ),
                    SettingsTile(
                      icon: Icons.add_to_drive_outlined,
                      title: 'Google Drive files',
                      subtitle: 'Only the files listed below, in your Drive.',
                    ),
                  ],
                ),
                const SettingsGroup(
                  label: 'Settings backup',
                  footer:
                      'Saves settings and API keys to Drive so a reinstall '
                      'loses nothing.',
                  dividers: false,
                  children: [BackupSection()],
                ),
                const SettingsGroup(
                  label: 'Files on Drive',
                  dividers: false,
                  children: [DriveFilesCard()],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Could not load calendar settings',
          subtitle: humanizeError(error),
        ),
      ),
    );
  }
}

/// What went wrong and what to check, based on the error text.
class _SignInErrorCard extends StatelessWidget {
  const _SignInErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final help = signInHelp(error);

    return AppCard(
      tier: AppCardTier.flat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: palette.warning, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  help.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final step in help.steps)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• $step',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            humanizeError(error),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain-language guidance for a failed Google sign-in.
({String title, List<String> steps}) signInHelp(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('cancel')) {
    return (
      title: 'Sign-in was cancelled',
      steps: const ['Tap "Sign in with Google" again and pick an account.'],
    );
  }
  if (text.contains('developer_error') ||
      text.contains('apiexception: 10') ||
      text.contains('12500') ||
      text.contains('sign_in_failed') ||
      text.contains('credential')) {
    return (
      title: 'Google rejected this build',
      steps: const [
        "The app's signing fingerprint (SHA-1) must be registered in the "
            'Firebase project for com.redpanda.personal.',
        'After adding it, download a fresh google-services.json and rebuild.',
        'It can take a few minutes for Google to pick up a new fingerprint.',
      ],
    );
  }
  if (text.contains('network') ||
      text.contains('socket') ||
      text.contains('timeout') ||
      text.contains('unreachable')) {
    return (
      title: "Couldn't reach Google",
      steps: const [
        'Check your internet connection and try again.',
        'If you use a VPN or restricted network, turn it off for a moment.',
      ],
    );
  }
  return (
    title: 'Sign-in failed',
    steps: const [
      'Make sure Google Play services is up to date.',
      'Try again, then check the message below if it keeps failing.',
    ],
  );
}
