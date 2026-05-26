import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uri_content/uri_content.dart';

import 'location_settings_service.dart';
import 'timeline_edits_file_finder.dart';
import 'timeline_edits_parser.dart';
import 'timeline_entry.dart';

final locationHistoryProvider =
    StateNotifierProvider<LocationHistoryNotifier, LocationHistorySummary>(
  (ref) => LocationHistoryNotifier(ref),
);

class LocationHistoryNotifier extends StateNotifier<LocationHistorySummary> {
  LocationHistoryNotifier(this._ref)
      : super(const LocationHistorySummary(entries: []));

  final Ref _ref;
  final _uriContent = UriContent();

  Future<void> loadFromConfiguredFolder() async {
    final settings = await _ref.read(locationSettingsProvider.future);
    if (settings.needsReselect) {
      throw FormatException(
        'Folder access expired. Open Location settings and choose the folder again.',
      );
    }

    final location = settings.pickedLocation;
    if (location == null) {
      throw FormatException(
        'No Timeline folder selected. Open Location settings from the menu.',
      );
    }

    final match = await findLatestTimelineEditsJson(location);
    if (match == null) {
      throw FormatException(
        'No Timeline Edits.json found in "${settings.displayLabel}".',
      );
    }

    await _importFromUri(match);
  }

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
    await _importContent(content, name);
  }

  Future<void> _importFromUri(TimelineEditsMatch match) async {
    final bytes = await _uriContent.from(match.uri);
    final content = utf8.decode(bytes);
    await _importContent(content, match.fileName);
  }

  Future<void> _importContent(String content, String name) async {
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
