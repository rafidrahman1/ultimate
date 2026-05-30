import 'package:dir_picker/dir_picker.dart';
import 'package:path/path.dart' as p;

/// Matches exports like `GameActivity_Export_2026-05-30_11-06-23.csv`.
final gameActivityCsvFileNamePattern = RegExp(
  r'^GameActivity_Export_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.csv$',
);

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

/// Finds the newest Game Activity CSV export inside a previously picked folder.
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

GameActivityCsvMatch? findLatestGameActivityEntry(
  Iterable<FileSystemEntry> entries, {
  String? folderPath,
}) {
  GameActivityCsvMatch? latest;
  DateTime? latestTimestamp;

  for (final entry in entries) {
    if (entry.isDirectory) continue;
    if (!gameActivityCsvFileNamePattern.hasMatch(entry.name)) continue;

    final uri = entry.uri;
    if (uri == null) continue;

    final timestamp = _timestampFromFileName(entry.name) ??
        entry.lastModified?.toUtc();
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

DateTime? _timestampFromFileName(String fileName) {
  final match = RegExp(
    r'^GameActivity_Export_(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})\.csv$',
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
