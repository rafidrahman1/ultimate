import 'dart:io';

import 'package:dir_picker/dir_picker.dart';
import 'package:path/path.dart' as p;

const legacyGameActivityExportFileName = 'GameActivity_Export.csv';

final gameActivityExportFileNamePattern = RegExp(
  r'^GameActivity_Export.*\.csv$',
);

bool isGameActivityExportFileName(String name) =>
    gameActivityExportFileNamePattern.hasMatch(name);

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

Future<void> deleteLegacyGameActivityExport(String folderPath) async {
  final legacy = File(p.join(folderPath, legacyGameActivityExportFileName));
  if (await legacy.exists()) {
    await legacy.delete();
  }
}

DateTime? _timestampFromFileName(String fileName) {
  final match = RegExp(
    r'GameActivity_Export_(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})\.csv$',
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
