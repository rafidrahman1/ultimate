import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal/core/error_display.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/features/settings/backup_service.dart';
import 'package:personal/features/settings/settings_status.dart';
import 'package:personal/shared/widgets/settings_kit.dart';

/// Back up / restore settings on Google Drive.
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
    ref.invalidate(backupInfoProvider);
    return 'Backed up ${info.entryCount} items';
  });

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'Settings on this device will be replaced '
          'by the backup. API keys and models are included.',
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
      ref.invalidate(aiSettingsProvider);
      return 'Restored $count items. Restart the app to apply everything.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final info = _info;
    final subtitle = _loading
        ? 'Checking for a backup…'
        : info == null
        ? 'No backup on Google Drive yet.'
        : 'Last ${DateFormat('d MMM yyyy · HH:mm').format(info.createdAt.toLocal())}'
              ' · ${info.entryCount} items';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsTile(
          icon: Icons.backup_outlined,
          title: 'Back up now',
          subtitle: subtitle,
          enabled: !_busy,
          onTap: _backUp,
          trailing: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        Divider(height: 1, indent: kSettingsRowInset, color: palette.border),
        SettingsTile(
          icon: Icons.restore_outlined,
          title: 'Restore from backup',
          subtitle: 'Replaces settings on this phone, API keys included.',
          enabled: !_busy && info != null,
          onTap: _restore,
        ),
      ],
    );
  }
}
