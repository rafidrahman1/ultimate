import 'package:dir_picker/dir_picker.dart';

/// Matches Cashew export names like `cashew-2026-05-24-14-27-46-480926.csv`.
final cashewCsvFileNamePattern =
    RegExp(r'^cashew-\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}-\d+\.csv$');

class CashewCsvMatch {
  const CashewCsvMatch({
    required this.fileName,
    required this.uri,
  });

  final String fileName;
  final Uri uri;
}

/// Finds the newest Cashew CSV export inside a previously picked folder.
Future<CashewCsvMatch?> findLatestCashewCsv(PickedLocation location) async {
  final entries = await DirPicker.listEntries(location, recursive: false);
  return findLatestCashewEntry(entries);
}

CashewCsvMatch? findLatestCashewEntry(Iterable<FileSystemEntry> entries) {
  CashewCsvMatch? latest;
  DateTime? latestTimestamp;

  for (final entry in entries) {
    if (entry.isDirectory) continue;
    if (!cashewCsvFileNamePattern.hasMatch(entry.name)) continue;

    final uri = entry.uri;
    if (uri == null) continue;

    final timestamp = _timestampFromCashewFileName(entry.name) ??
        entry.lastModified?.toUtc();
    if (timestamp == null) continue;

    if (latestTimestamp == null || timestamp.isAfter(latestTimestamp)) {
      latestTimestamp = timestamp;
      latest = CashewCsvMatch(fileName: entry.name, uri: uri);
    }
  }

  return latest;
}

DateTime? _timestampFromCashewFileName(String fileName) {
  final match = RegExp(
    r'^cashew-(\d{4})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-(\d+)\.csv$',
  ).firstMatch(fileName);
  if (match == null) return null;

  try {
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
      int.parse(match.group(7)!),
    );
  } catch (_) {
    return null;
  }
}
