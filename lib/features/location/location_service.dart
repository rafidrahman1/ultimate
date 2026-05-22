import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'timeline_edits_parser.dart';
import 'timeline_entry.dart';

final locationHistoryProvider =
    StateNotifierProvider<LocationHistoryNotifier, LocationHistorySummary>(
  (ref) => LocationHistoryNotifier(),
);

class LocationHistoryNotifier extends StateNotifier<LocationHistorySummary> {
  LocationHistoryNotifier()
      : super(const LocationHistorySummary(entries: []));

  Future<void> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final name = file.name;
    final path = file.path;
    if (path == null) {
      throw FormatException('Could not read "$name"');
    }

    final content = await File(path).readAsString();
    if (content.trim().isEmpty) {
      throw FormatException('File "$name" is empty');
    }

    final entries = await compute(parseTimelineEditsJson, content);
    if (entries.isEmpty) {
      throw FormatException(
        'No visits or trips found in "$name". '
        'Import a Google Takeout Timeline Edits.json file.',
      );
    }

    state = LocationHistorySummary(entries: entries, fileName: name);
  }

  void clear() {
    state = const LocationHistorySummary(entries: []);
  }
}
