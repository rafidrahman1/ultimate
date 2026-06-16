import 'dart:io';

import 'package:dir_picker/dir_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

bool isGameActivityExportFileName(String name) =>
    name.startsWith('GameActivity_Export');

class GameActivityCsvMatch {
  const GameActivityCsvMatch({
    required this.fileName,
    required this.uri,
    this.filePath,
  });

  final String fileName;
  final Uri uri;
  final String? filePath;
}

Future<GameActivityCsvMatch?> findLatestGameActivityCsv(
  PickedLocation location,
) async {
  final entries = await DirPicker.listEntries(location, recursive: false);
  String? folderPath;
  final uri = location.uri;
  if (uri != null && uri.scheme == 'file') {
    folderPath = uri.toFilePath();
  }
  return findLatestGameActivityEntry(entries, folderPath: folderPath);
}

Future<GameActivityCsvMatch?> findLatestGameActivityCsvOnDisk(
  String folderPath,
) async {
  final dir = Directory(folderPath);
  if (!await dir.exists()) return null;

  final entries = <FileSystemEntry>[];
  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (!isGameActivityExportFileName(name)) continue;
    entries.add(
      FileSystemEntry(
        name: name,
        relativePath: name,
        isDirectory: false,
        uri: Uri.file(entity.path),
        lastModified: await entity.lastModified(),
      ),
    );
  }

  return findLatestGameActivityEntry(entries, folderPath: folderPath);
}

GameActivityCsvMatch? findLatestGameActivityEntry(
  Iterable<FileSystemEntry> entries, {
  String? folderPath,
}) {
  GameActivityCsvMatch? latest;
  DateTime? latestTimestamp;

  for (final entry in entries) {
    if (entry.isDirectory) continue;
    if (!isGameActivityExportFileName(entry.name)) continue;

    final uri = entry.uri;
    if (uri == null) continue;

    final timestamp =
        _timestampFromFileName(entry.name) ?? entry.lastModified?.toUtc();
    if (timestamp == null) continue;

    if (latestTimestamp == null || timestamp.isAfter(latestTimestamp)) {
      latestTimestamp = timestamp;
      latest = GameActivityCsvMatch(
        fileName: entry.name,
        uri: uri,
        filePath: folderPath != null ? p.join(folderPath, entry.name) : null,
      );
    }
  }

  return latest;
}

Future<void> deleteStaleGameActivityExportsFromLocation(
  PickedLocation location, {
  required String keepFileName,
}) async {
  final entries = await DirPicker.listEntries(location, recursive: false);
  String? folderPath;
  final uri = location.uri;
  if (uri != null && uri.scheme == 'file') {
    folderPath = uri.toFilePath();
  }

  for (final entry in entries) {
    if (entry.isDirectory) continue;
    if (entry.name == keepFileName) continue;
    if (!isGameActivityExportFileName(entry.name)) continue;
    await _deleteFileSystemEntry(entry, folderPath: folderPath);
  }
}

Future<void> deleteStaleGameActivityExportsOnDisk(
  String folderPath, {
  required String keepFileName,
}) async {
  final dir = Directory(folderPath);
  if (!await dir.exists()) return;

  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (name == keepFileName) continue;
    if (!isGameActivityExportFileName(name)) continue;
    try {
      await entity.delete();
    } catch (_) {
      // Best effort.
    }
  }
}

Future<void> _deleteFileSystemEntry(
  FileSystemEntry entry, {
  String? folderPath,
}) async {
  if (folderPath != null) {
    final file = File(p.join(folderPath, entry.name));
    if (await file.exists()) {
      await file.delete();
      return;
    }
  }

  final uri = entry.uri;
  if (uri == null) return;

  if (uri.scheme == 'file') {
    final file = File(uri.toFilePath());
    if (await file.exists()) {
      await file.delete();
    }
    return;
  }

  if (Platform.isAndroid && uri.scheme == 'content') {
    await _deleteAndroidDocument(uri);
  }
}

Future<void> _deleteAndroidDocument(Uri uri) async {
  const channel = MethodChannel('com.redpanda.personal/document_io');
  try {
    await channel.invokeMethod<bool>('deleteDocument', {'uri': uri.toString()});
  } catch (_) {
    // Best effort.
  }
}

DateTime? _timestampFromFileName(String fileName) {
  final match = RegExp(
    r'GameActivity_Export_(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})',
  ).firstMatch(fileName);
  if (match == null) return null;

  try {
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  } catch (_) {
    return null;
  }
}
