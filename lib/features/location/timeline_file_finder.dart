import 'dart:io';

import 'package:dir_picker/dir_picker.dart';
import 'package:flutter/services.dart';

import 'package:personal/core/app_log.dart';

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

/// Deletes every other Timeline export in [location], keeping only
/// [keepFileName] (the one just read).
Future<void> deleteStaleTimelineExportsFromLocation(
  PickedLocation location, {
  required String keepFileName,
}) async {
  final entries = await DirPicker.listEntries(location, recursive: false);

  for (final entry in entries) {
    if (entry.isDirectory) continue;
    if (entry.name == keepFileName) continue;
    if (!isTimelineExportFileName(entry.name)) continue;
    await _deleteFileSystemEntry(entry);
  }
}

Future<void> _deleteFileSystemEntry(FileSystemEntry entry) async {
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
  } catch (error) {
    // Best effort.
    AppLog.warn('Failed to delete Android document $uri: $error');
  }
}
