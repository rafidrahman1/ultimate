import 'package:dir_picker/dir_picker.dart';

/// Google Takeout export name for timeline edits (case-insensitive).
final timelineEditsFileNamePattern = RegExp(
  r'^timeline edits\.json$',
  caseSensitive: false,
);

class TimelineEditsMatch {
  const TimelineEditsMatch({
    required this.fileName,
    required this.uri,
  });

  final String fileName;
  final Uri uri;
}

/// Finds the newest Timeline Edits.json inside a previously picked folder.
Future<TimelineEditsMatch?> findLatestTimelineEditsJson(
  PickedLocation location,
) async {
  final entries = await DirPicker.listEntries(location, recursive: false);
  return findLatestTimelineEditsEntry(entries);
}

TimelineEditsMatch? findLatestTimelineEditsEntry(
  Iterable<FileSystemEntry> entries,
) {
  TimelineEditsMatch? latest;
  DateTime? latestModified;

  for (final entry in entries) {
    if (entry.isDirectory) continue;
    if (!timelineEditsFileNamePattern.hasMatch(entry.name)) continue;

    final uri = entry.uri;
    if (uri == null) continue;

    final modified = entry.lastModified?.toUtc();
    if (modified == null) continue;

    if (latestModified == null || modified.isAfter(latestModified)) {
      latestModified = modified;
      latest = TimelineEditsMatch(fileName: entry.name, uri: uri);
    }
  }

  return latest;
}
