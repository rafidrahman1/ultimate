import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/auth/google_drive_client.dart';
import 'package:personal/features/location/data/timeline_drive_backup.dart';
import 'package:personal/features/location/recording/location_recorder.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/settings_kit.dart';
import 'package:personal/shared/widgets/status_message.dart';

/// Recording the timeline on the phone and saving it to Google Drive.
class LocationSettingsScreen extends ConsumerWidget {
  const LocationSettingsScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    final controller = ref.read(locationRecorderProvider.notifier);
    if (!on) {
      await controller.disable();
      return;
    }
    final started = await controller.enable();
    if (!started && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Recording needs location access. Allow it and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final statusColors = context.statusColors;
    final status = ref.watch(locationRecorderProvider).value;
    final backup = ref.watch(timelineDriveBackupProvider);
    final backupController = ref.read(timelineDriveBackupProvider.notifier);

    final Widget body;
    if (status == null) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (!status.supported) {
      body = const StatusMessage(
        icon: Icons.location_off_outlined,
        title: 'Recording the timeline is only available on Android.',
      );
    } else {
      final on = status.enabled && status.running;
      final warnings = status.warnings;
      final (String headline, Color? tone) = !status.enabled
          ? ('Not recording', null)
          : warnings.isNotEmpty
          ? (
              warnings.length == 1
                  ? 'Recording, with 1 problem'
                  : 'Recording, with ${warnings.length} problems',
              statusColors.warning,
            )
          : on
          ? ('Recording · ${_lastFixLabel(status.lastFix)}', statusColors.good)
          : ('Starting…', null);

      final backupError = backup.error;
      final backupSubtitle = backup.saving
          ? 'Saving…'
          : backupError ??
                (backup.lastSaved == null
                    ? 'As ${DriveFolders.app}/${DriveFiles.timeline}, in the '
                          'Google export format'
                    : 'Saved ${_agoLabel(backup.lastSaved!)} to '
                          '${DriveFolders.app}/${DriveFiles.timeline}');

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsPageHeader(
            icon: on ? Icons.radar_rounded : Icons.location_off_outlined,
            title: 'Location timeline',
            status: headline,
            statusColor: tone,
            description:
                'Detects visits and trips on this phone, like Google Maps '
                'Timeline, and adds them after your last Timeline export.',
            actions: [
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.locationTimeline),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('Review & fix timeline'),
              ),
            ],
          ),
          SettingsGroup(
            label: 'Recording',
            children: [
              SettingsSwitchTile(
                icon: Icons.radar_rounded,
                iconColor: palette.mobility,
                title: 'Record my timeline',
                subtitle: 'Runs in the background with location access.',
                value: status.enabled,
                onChanged: (v) => _toggle(context, ref, v),
              ),
              for (final warning in warnings)
                SettingsTile(
                  icon: Icons.warning_amber_rounded,
                  iconColor: statusColors.warning,
                  title: warning,
                  trailing: FilledButton.tonal(
                    onPressed: () => ref
                        .read(locationRecorderProvider.notifier)
                        .fixPermissions(),
                    child: const Text('Fix'),
                  ),
                ),
            ],
          ),
          SettingsGroup(
            label: 'Google Drive',
            footer:
                'Your corrections are saved with it, so the next export picks '
                'them up.',
            children: [
              SettingsSwitchTile(
                icon: Icons.cloud_upload_outlined,
                title: 'Save timeline to Drive',
                subtitle: backupSubtitle,
                value: backup.enabled,
                onChanged: backup.saving ? null : backupController.setEnabled,
              ),
              if (backup.enabled)
                SettingsTile(
                  title: 'Save now',
                  enabled: !backup.saving,
                  onTap: backupController.saveNow,
                  trailing: backup.saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.sync_rounded, color: palette.accent),
                ),
            ],
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppScreenAppBar.build(context, ref, title: 'Location timeline'),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: [body],
        ),
      ),
    );
  }
}

String _agoLabel(DateTime time) {
  final ago = clock.now().difference(time);
  if (ago.inMinutes < 1) return 'just now';
  if (ago.inMinutes < 60) return '${ago.inMinutes} min ago';
  if (ago.inHours < 24) return '${ago.inHours} h ago';
  return '${ago.inDays} d ago';
}

String _lastFixLabel(DateTime? lastFix) {
  if (lastFix == null) return 'waiting for the first location';
  final ago = clock.now().difference(lastFix);
  if (ago.inMinutes < 1) return 'location just now';
  if (ago.inMinutes < 60) return 'last location ${ago.inMinutes} min ago';
  if (ago.inHours < 24) return 'last location ${ago.inHours} h ago';
  return 'last location ${ago.inDays} d ago';
}
