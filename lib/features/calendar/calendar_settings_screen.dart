import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/app_screen_app_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_message.dart';
import '../auth/google_account_service.dart';
import 'calendar_service.dart';
import 'calendar_settings_service.dart';

class CalendarSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSettingsScreen> createState() =>
      _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState extends ConsumerState<CalendarSettingsScreen> {
  bool _connecting = false;

  Future<void> _connect() async {
    setState(() => _connecting = true);
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
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppScreenAppBar.build(context, ref, title: 'Google account'),
      body: settingsAsync.when(
        data: (settings) {
          final isConnected = settings.isConnected || authUser != null;
          final accountLabel = settings.isConnected
              ? settings.displayLabel
              : authUser?.email ?? settings.displayLabel;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SectionHeader(
                'Google account',
                subtitle:
                    'One sign-in for calendar sync, profile backup, and '
                    'cross-device personal information. Read-only calendar access '
                    'includes Bangladesh public holidays.',
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(
                    Icons.account_circle_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    isConnected ? 'Account connected' : 'No account connected',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(accountLabel),
                ),
              ),
              const SizedBox(height: 16),
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
                  _connecting ? 'Signing in...' : 'Sign in with Google',
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
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Could not load calendar settings',
          subtitle: error.toString(),
        ),
      ),
    );
  }
}
