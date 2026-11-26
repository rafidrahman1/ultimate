import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/error_display.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/health/data/health_service.dart';
import 'package:personal/features/health/ui/health_vitals_sections.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/settings_kit.dart';

/// Health Connect access: whether the app is connected, what each metric
/// can read, and how to get Samsung Health data flowing into it.
class HealthSettingsScreen extends ConsumerWidget {
  const HealthSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(healthAuthorizationProvider);
    final status = context.statusColors;

    final (String headline, Color? tone) = authAsync.when(
      data: (ok) => ok
          ? ('Connected to Health Connect', status.good)
          : ('Access not granted yet', status.warning),
      loading: () => ('Checking access…', null),
      error: (error, _) => (humanizeError(error), status.critical),
    );
    final authorized = authAsync.value ?? false;

    return Scaffold(
      appBar: AppScreenAppBar.build(context, ref, title: 'Health Connect'),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: [
            SettingsPageHeader(
              icon: Icons.monitor_heart_outlined,
              title: 'Health Connect',
              status: headline,
              statusColor: tone,
              description:
                  'Sleep, steps, heart and workouts are read from Health '
                  'Connect on this phone. Nothing is written back.',
              actions: [
                if (!authorized && !authAsync.isLoading)
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(healthAuthorizationProvider),
                    child: const Text('Grant access'),
                  ),
              ],
            ),
            const _AccessGroup(),
            const SettingsGroup(
              label: 'Getting Samsung Health data',
              footer:
                  'The app reads Health Connect, not Samsung Health. If the '
                  'numbers differ, Samsung Health has not synced yet.',
              dividers: false,
              children: [
                _Step(1, 'Open Samsung Health → Settings → Health Connect.'),
                _Step(
                  2,
                  'Turn on sync for Sleep, Steps, Heart rate and Exercise.',
                ),
                _Step(
                  3,
                  'In Health Connect → App permissions → Samsung Health, '
                  'allow the same types.',
                ),
                _Step(
                  4,
                  'Pull to refresh the Health screen. Still behind? Open '
                  'Samsung Health once to force a sync.',
                  last: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-metric access and how many days arrived this month, with a button
/// to review access.
class _AccessGroup extends ConsumerStatefulWidget {
  const _AccessGroup();

  @override
  ConsumerState<_AccessGroup> createState() => _AccessGroupState();
}

class _AccessGroupState extends ConsumerState<_AccessGroup> {
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
    final vitals = ref.watch(monthlyHealthDataProvider).value?.vitals;
    final connected = vitals?.isConnected ?? false;

    return SettingsGroup(
      label: 'What the app can read',
      footer: 'Day counts are for the selected month.',
      trailing: TextButton(
        onPressed: _busy ? null : _review,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        child: Text(
          _busy
              ? 'Waiting…'
              : connected
              ? 'Review access'
              : 'Connect activity & heart',
        ),
      ),
      dividers: false,
      children: [
        SettingsTile(
          icon: Icons.bedtime_outlined,
          iconColor: context.palette.health,
          title: 'Sleep',
          subtitle: 'Read with the main Health Connect access.',
        ),
        Divider(height: 1, color: context.palette.border),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: VitalsStatusPanel(vitals: vitals),
        ),
      ],
    );
  }
}

/// One numbered setup step, joined to the next by a line.
class _Step extends StatelessWidget {
  const _Step(this.number, this.text, {this.last = false});

  final int number;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Container(
                    width: 1,
                    height: AppSpacing.md,
                    color: number == 1 ? Colors.transparent : palette.border,
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.health.withValues(
                        alpha: AppOpacity.medium,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$number',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: palette.health,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 1,
                      color: last ? Colors.transparent : palette.border,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md + 4),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: AppSpacing.md + 3,
                  bottom: last ? AppSpacing.lg : AppSpacing.sm,
                ),
                child: Text(text, style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
