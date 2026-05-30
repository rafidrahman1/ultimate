import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/section_header.dart';
import '../../widgets/status_message.dart';
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
        const SnackBar(content: Text('Google Calendar connected')),
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
      const SnackBar(content: Text('Google account disconnected')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(calendarSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar settings')),
      body: settingsAsync.when(
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SectionHeader(
                'Google Calendar sync',
                subtitle:
                    'Read-only access to your primary calendar plus Bangladesh '
                    'public holidays. Events sync for the location timeline month '
                    'and the following month.',
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
                    settings.isConnected
                        ? 'Account connected'
                        : 'No account connected',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(settings.displayLabel),
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
                  _connecting ? 'Connecting...' : 'Connect Google account',
                ),
              ),
              if (settings.isConnected) ...[
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
