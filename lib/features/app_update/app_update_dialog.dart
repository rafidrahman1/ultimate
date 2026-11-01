import 'package:flutter/material.dart';

import 'package:personal/features/app_update/app_update_service.dart';

/// Prompts to install [update]. Resolves after the dialog closes.
Future<void> showAppUpdateDialog(
  BuildContext context,
  AppUpdateService service,
  AppUpdate update,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _UpdateDialog(service: service, update: update),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.service, required this.update});

  final AppUpdateService service;
  final AppUpdate update;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      await widget.service.downloadAndInstall(
        widget.update,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final downloading = _progress != null;
    final mb = update.sizeBytes / (1024 * 1024);
    return AlertDialog(
      title: Text('Update available: ${update.version}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (update.notes.isNotEmpty) Text(update.notes),
            if (update.sizeBytes > 0)
              Text('\nSize: ${mb.toStringAsFixed(1)} MB'),
            if (downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: downloading ? null : _install,
          child: Text(_error == null ? 'Update' : 'Retry'),
        ),
      ],
    );
  }
}
