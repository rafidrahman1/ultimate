import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal/app/router.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/location/data/timeline_drive_backup.dart';
import 'package:personal/features/location/recording/location_recorder.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Turns the on-phone timeline recorder on or off and shows if it's healthy.
class RecordingCard extends ConsumerWidget {
  const RecordingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(locationRecorderProvider).value;
    if (status == null || !status.supported) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.mobility(context);
    final on = status.enabled && status.running;

    Future<void> toggle(bool value) async {
      final controller = ref.read(locationRecorderProvider.notifier);
      if (!value) {
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

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                on ? Icons.radar_rounded : Icons.location_off_outlined,
                color: on ? accent : palette.textMuted,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record my timeline',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      on
                          ? 'On · ${_lastFixLabel(status.lastFix)}'
                          : 'Detects visits and trips on this phone, like '
                                'Google Maps Timeline',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: status.enabled, onChanged: toggle),
            ],
          ),
          for (final warning in status.warnings)
            InkWell(
              onTap: () =>
                  ref.read(locationRecorderProvider.notifier).fixPermissions(),
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: palette.warning,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        warning,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const _DriveBackupRow(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.locationTimeline),
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: const Text('Review & fix timeline'),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Save to Google Drive" as Timeline/Timeline.json.
class _DriveBackupRow extends ConsumerWidget {
  const _DriveBackupRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backup = ref.watch(timelineDriveBackupProvider);
    final controller = ref.read(timelineDriveBackupProvider.notifier);
    final theme = Theme.of(context);
    final palette = context.palette;
    final error = backup.error;
    final subtitle = backup.saving
        ? 'Saving…'
        : error ??
              (backup.lastSaved == null
                  ? 'As $timelineDriveFolderName/$timelineDriveFileName, '
                        'in the Google export format'
                  : 'Saved ${_agoLabel(backup.lastSaved!)} to '
                        '$timelineDriveFolderName/$timelineDriveFileName');

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.cloud_upload_outlined, color: palette.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save to Google Drive',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: error != null && !backup.saving
                        ? palette.warning
                        : palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (backup.enabled)
            IconButton(
              tooltip: 'Save now',
              onPressed: backup.saving ? null : controller.saveNow,
              icon: const Icon(Icons.sync_rounded),
            ),
          Switch(
            value: backup.enabled,
            onChanged: backup.saving ? null : controller.setEnabled,
          ),
        ],
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
