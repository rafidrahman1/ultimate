import 'package:dir_picker/dir_picker.dart';
import 'package:path/path.dart' as p;

const gameActivityExportFileName = 'GameActivity_Export.csv';

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

Future<GameActivityCsvMatch?> findGameActivityCsv(PickedLocation location) async {
  final entries = await DirPicker.listEntries(location, recursive: false);
  String? folderPath;
  final uri = location.uri;
  if (uri != null && uri.scheme == 'file') {
    folderPath = uri.toFilePath();
  }
  return findGameActivityEntry(entries, folderPath: folderPath);
}

GameActivityCsvMatch? findGameActivityEntry(
  Iterable<FileSystemEntry> entries, {
  String? folderPath,
}) {
  for (final entry in entries) {
    if (entry.isDirectory) continue;
    if (entry.name != gameActivityExportFileName) continue;

    final uri = entry.uri;
    if (uri == null) continue;

    return GameActivityCsvMatch(
      fileName: entry.name,
      uri: uri,
      filePath: folderPath != null ? p.join(folderPath, entry.name) : null,
    );
  }

  return null;
}
