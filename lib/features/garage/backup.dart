import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:motohealth/core/app_log.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// The backup file's content: all the data as pretty JSON.
String backupJson(MotoData data) =>
    const JsonEncoder.withIndent('  ').convert(data.toJson());

/// Reads a backup, or returns null when [text] isn't one of ours.
MotoData? parseBackup(String text) {
  try {
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic> || json['bikes'] is! List) return null;
    return MotoData.fromJson(json);
  } catch (error) {
    AppLog.warn('Not a valid backup: $error');
    return null;
  }
}

String _backupName() =>
    'motohealth-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';

/// Asks where to put the backup (Downloads, Drive, ...) and saves it there.
Future<void> saveBackup(
  BuildContext context,
  WidgetRef ref,
  MotoData data,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save backup',
    fileName: _backupName(),
    type: FileType.custom,
    allowedExtensions: const ['json'],
    bytes: Uint8List.fromList(utf8.encode(backupJson(data))),
  );
  if (path == null) return;
  await ref.read(motoStoreProvider.notifier).markBackedUp(DateTime.now());
  messenger.showSnackBar(const SnackBar(content: Text('Backup saved.')));
}

/// Writes the backup to a file and opens the share sheet (email, chat, ...).
Future<void> shareBackup(
  BuildContext context,
  WidgetRef ref,
  MotoData data,
) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${_backupName()}');
  await file.writeAsString(backupJson(data), flush: true);
  final result = await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: 'MotoHealth backup'),
  );
  if (result.status == ShareResultStatus.success) {
    await ref.read(motoStoreProvider.notifier).markBackedUp(DateTime.now());
  }
}

/// Picks a backup file and, after confirming, replaces all data with it.
Future<void> importBackup(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await FilePicker.platform.pickFiles(withData: true);
  final bytes = picked?.files.single.bytes;
  if (bytes == null) return;

  final backup = parseBackup(utf8.decode(bytes, allowMalformed: true));
  if (backup == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('That is not a MotoHealth backup.')),
    );
    return;
  }
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Replace all data?'),
      content: Text(
        'This backup has ${backup.bikes.length} bike(s), '
        '${backup.fuel.length} fill-ups and ${backup.services.length} '
        'services. Everything currently in the app will be replaced.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Replace'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await ref.read(motoStoreProvider.notifier).restore(backup);
  messenger.showSnackBar(const SnackBar(content: Text('Backup restored.')));
}
