import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/app_log.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/status_message.dart';

/// Shows the on-device warning log so a failure on a release build can be
/// read, copied or cleared.
class DiagnosticsLogScreen extends ConsumerStatefulWidget {
  const DiagnosticsLogScreen({super.key});

  @override
  ConsumerState<DiagnosticsLogScreen> createState() =>
      _DiagnosticsLogScreenState();
}

class _DiagnosticsLogScreenState extends ConsumerState<DiagnosticsLogScreen> {
  String? _log;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await AppLog.read();
    if (mounted) setState(() => _log = log);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _log ?? ''));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Log copied')));
  }

  Future<void> _clear() async {
    await AppLog.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final log = _log;
    final hasLog = log != null && log.isNotEmpty;
    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Diagnostics log',
        extraActions: [
          AppBarCircularAction(
            icon: Icons.copy,
            tooltip: 'Copy',
            onPressed: hasLog ? _copy : null,
          ),
          AppBarCircularAction(
            icon: Icons.delete_outline,
            tooltip: 'Clear',
            onPressed: hasLog ? _clear : null,
          ),
        ],
      ),
      body: switch (log) {
        null => const Center(child: CircularProgressIndicator()),
        '' => const StatusMessage(
          icon: Icons.check_circle_outline,
          title: 'Nothing logged',
          subtitle: 'Warnings and failed requests will show up here.',
        ),
        _ => SingleChildScrollView(
          reverse: true,
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: SelectableText(
            log,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      },
    );
  }
}
