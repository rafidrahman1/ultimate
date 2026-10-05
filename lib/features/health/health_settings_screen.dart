import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/section_header.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_vitals_sections.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/content_width.dart';

class HealthSettingsScreen extends ConsumerWidget {
  const HealthSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(healthAuthorizationProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppScreenAppBar.build(context, ref, title: 'Health settings'),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            const SectionHeader(
              'Authorization',
              subtitle: 'Connect this app to Health Connect on your device.',
            ),
            const SizedBox(height: 12),
            authAsync.when(
              data: (isAuthorized) => _AuthCard(
                isAuthorized: isAuthorized,
                onAuthorize: () => ref.invalidate(healthAuthorizationProvider),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text(
                'Error: $err',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),

            const SizedBox(height: 32),
            const SectionHeader(
              'Samsung Health sync',
              subtitle:
                  'Enable sharing in Samsung Health so data appears here.',
            ),
            const SizedBox(height: 16),
            const _SyncStep(number: '1', text: 'Open the Samsung Health app.'),
            const _SyncStep(
              number: '2',
              text: 'Go to Settings → Health Connect.',
            ),
            const _SyncStep(
              number: '3',
              text: 'Turn on sync for Sleep, Steps, Heart rate and Exercise.',
            ),
            const _SyncStep(
              number: '4',
              text:
                  'Open Health Connect → App permissions → Samsung Health → allow the same types.',
            ),
            const _SyncStep(
              number: '5',
              text:
                  'Return here and tap Refresh on the Health screen. If counts still differ, open Samsung Health once to force a sync.',
            ),
            const SizedBox(height: 12),
            Text(
              'This app reads health data from Health Connect, not directly from Samsung Health. '
              'If Samsung Health shows different values, the data may not be synced to Health Connect yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            const SectionHeader(
              'Data from Health Connect',
              subtitle:
                  'What Personal can read right now, and how much arrived '
                  'in the selected month.',
            ),
            const SizedBox(height: 8),
            const _DataTypeRow(icon: Icons.bedtime, title: 'Sleep'),
            const SizedBox(height: 8),
            const _VitalsAccess(),
          ],
        ),
      ),
    );
  }
}

/// Per-metric access and data counts, with a button to review access.
class _VitalsAccess extends ConsumerStatefulWidget {
  const _VitalsAccess();

  @override
  ConsumerState<_VitalsAccess> createState() => _VitalsAccessState();
}

class _VitalsAccessState extends ConsumerState<_VitalsAccess> {
  bool _busy = false;

  Future<void> _review() async {
    setState(() => _busy = true);
    try {
      await ref.read(healthServiceProvider).requestVitalsPermissions();
      await ref.read(monthlyHealthDataProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vitals = ref.watch(monthlyHealthDataProvider).valueOrNull?.vitals;
    final connected = vitals?.isConnected ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VitalsStatusPanel(vitals: vitals),
        const SizedBox(height: AppSpacing.md),
        FilledButton.tonal(
          onPressed: _busy ? null : _review,
          child: Text(
            _busy
                ? 'Waiting for Health Connect…'
                : connected
                ? 'Review access'
                : 'Connect activity and heart data',
          ),
        ),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.isAuthorized, required this.onAuthorize});

  final bool isAuthorized;
  final VoidCallback onAuthorize;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = isAuthorized ? palette.accent : palette.warning;

    return AppCard(
      tier: isAuthorized ? AppCardTier.hero : AppCardTier.raised,
      child: Row(
        children: [
          Icon(
            isAuthorized ? Icons.check_circle : Icons.warning_amber_rounded,
            color: color,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAuthorized ? 'Connected' : 'Authorization required',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  isAuthorized
                      ? 'Health Connect is ready'
                      : 'Grant permissions to read Samsung Health data',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.textMuted),
                ),
              ],
            ),
          ),
          if (!isAuthorized)
            FilledButton(
              onPressed: onAuthorize,
              child: const Text('Authorize'),
            ),
        ],
      ),
    );
  }
}

class _SyncStep extends StatelessWidget {
  const _SyncStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              number,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _DataTypeRow extends StatelessWidget {
  const _DataTypeRow({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
    );
  }
}
