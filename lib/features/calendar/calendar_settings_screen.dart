import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/error_display.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/calendar_service.dart';
import 'package:personal/features/calendar/calendar_settings_service.dart';
import 'package:personal/core/theme/app_theme.dart';

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
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final summary = ref.watch(calendarSummaryProvider);
    final theme = Theme.of(context);
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

          return ContentWidth(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                AppCard(
                  tier: isConnected ? AppCardTier.hero : AppCardTier.raised,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: palette.accent.withValues(
                          alpha: AppOpacity.medium,
                        ),
                        backgroundImage: photo != null
                            ? NetworkImage(photo)
                            : null,
                        onBackgroundImageError: photo != null
                            ? (_, _) {}
                            : null,
                        child: photo == null
                            ? Icon(
                                Icons.account_circle_outlined,
                                color: palette.accent,
                                size: 30,
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConnected
                                  ? (name ?? 'Account connected')
                                  : 'Not signed in',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (email != null && email.isNotEmpty)
                              Text(
                                email,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: palette.textMuted,
                                ),
                              ),
                            const SizedBox(height: AppSpacing.sm),
                            _StateChip(connected: isConnected),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_signInError != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _SignInErrorCard(error: _signInError!),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _connecting ? null : _connect,
                  icon: _connecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    _connecting
                        ? 'Signing in...'
                        : isConnected
                        ? 'Sign in again'
                        : 'Sign in with Google',
                  ),
                ),
                if (isConnected) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _connecting ? null : _disconnect,
                    icon: const Icon(Icons.logout),
                    label: const Text('Disconnect'),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                Text('WHAT THIS SYNCS', style: context.sectionLabel),
                const SizedBox(height: AppSpacing.sm),
                const AppCard(
                  tier: AppCardTier.flat,
                  child: Column(
                    children: [
                      _SyncPoint(
                        icon: Icons.calendar_month_outlined,
                        title: 'Calendar events',
                        body:
                            'Read-only access, including Bangladesh public '
                            'holidays. Nothing is written back.',
                      ),
                      SizedBox(height: AppSpacing.md),
                      _SyncPoint(
                        icon: Icons.backup_outlined,
                        title: 'Personal information',
                        body:
                            'Only your profile syncs, scoped to your account, '
                            'so a new device can pick it up.',
                      ),
                      SizedBox(height: AppSpacing.md),
                      _SyncPoint(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Cashew expenses',
                        body: 'Reads Cashew/outbox.csv from your Drive.',
                      ),
                    ],
                  ),
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

class _StateChip extends StatelessWidget {
  const _StateChip({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = connected ? palette.accent : palette.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.medium),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        connected ? 'Connected' : 'Local only',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SyncPoint extends StatelessWidget {
  const _SyncPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.palette.accent),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
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
                    fontWeight: FontWeight.w800,
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
