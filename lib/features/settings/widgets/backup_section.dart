import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/backup_service.dart';
import 'package:personal/core/error_display.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/features/results/selected_checklist_result_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Back up / restore settings and checklist progress in the data folder.
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  static const _service = BackupService();

  BackupInfo? _info;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final info = await _service.peek();
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    String message;
    try {
      message = await action();
    } catch (error) {
      message = humanizeError(error);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    await _refresh();
  }

  Future<void> _backUp() => _run(() async {
    final info = await _service.backUp();
    return 'Backed up ${info.entryCount} items';
  });

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'Settings and checklist progress on this device will be replaced '
          'by the backup. API keys are not included.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final count = await _service.restore();
      ref
        ..invalidate(selectedChecklistResultIdProvider)
        ..invalidate(aiSettingsProvider)
        ..invalidate(analysisResultsProvider);
      return 'Restored $count items. Restart the app to apply everything.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = _info;
    final subtitle = _loading
        ? 'Checking for a backup...'
        : info == null
        ? 'No backup in the data folder yet.'
        : 'Last backup ${DateFormat('d MMM yyyy · HH:mm').format(info.createdAt.toLocal())}'
              ' · ${info.entryCount} items';

    return AppCard(
      tier: AppCardTier.flat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _backUp,
                  icon: const Icon(Icons.backup_outlined, size: 18),
                  label: const Text('Back up now'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || info == null ? null : _restore,
                  icon: const Icon(Icons.restore_outlined, size: 18),
                  label: const Text('Restore'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
