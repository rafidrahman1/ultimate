import 'package:dir_picker/dir_picker.dart';

/// Numbered copies use a space: `Timeline (1).json`, not `Timeline(1).json`.
final timelineNumberedJsonFileNamePattern = RegExp(
  r'^timeline \(\d+\)\.json$',
  caseSensitive: false,
);

bool isTimelineExportFileName(String name) {
  final lower = name.toLowerCase();
  return lower == 'timeline.json' ||
      timelineNumberedJsonFileNamePattern.hasMatch(lower);
}

class TimelineJsonMatch {
  const TimelineJsonMatch({required this.fileName, required this.uri});

  final String fileName;
  final Uri uri;
}

/// Finds the newest Timeline export JSON inside a previously picked folder.
Future<TimelineJsonMatch?> findTimelineJson(PickedLocation location) async {
  final entries = await DirPicker.listEntries(location, recursive: false);
  return findLatestTimelineEntry(entries);
}

TimelineJsonMatch? findLatestTimelineEntry(Iterable<FileSystemEntry> entries) {
  TimelineJsonMatch? latest;
  DateTime? latestModifiedAt;

  for (final entry in entries) {
    if (entry.isDirectory) continue;
    if (!isTimelineExportFileName(entry.name)) continue;
    final uri = entry.uri;
    if (uri == null) continue;

    final modifiedAt = entry.lastModified?.toUtc();
    if (latestModifiedAt == null ||
        (modifiedAt != null && modifiedAt.isAfter(latestModifiedAt))) {
      latest = TimelineJsonMatch(fileName: entry.name, uri: uri);
      latestModifiedAt =
          modifiedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
  }
  return latest;
}
