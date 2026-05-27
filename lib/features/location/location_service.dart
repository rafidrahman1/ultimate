import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uri_content/uri_content.dart';

import 'location_settings_service.dart';
import 'timeline_file_finder.dart';
import 'timeline_activity.dart';

const _defaultTimelinePath =
    r"c:\Users\DOC\CrossDevice\Rafid's S22\storage\Download\Timeline\Timeline.json";

final locationSummaryProvider =
    StateNotifierProvider<LocationSummaryNotifier, LocationSummary>((ref) {
      return LocationSummaryNotifier(ref);
    });

class LocationSummaryNotifier extends StateNotifier<LocationSummary> {
  LocationSummaryNotifier(this._ref)
    : super(const LocationSummary(activities: []));

  final Ref _ref;
  final _uriContent = UriContent();

  Future<void> loadAuto() async {
    final settings = await _ref.read(locationSettingsProvider.future);
    if (settings.hasFolder && !settings.needsReselect) {
      await loadFromConfiguredFolder();
      return;
    }
    await loadFromDefaultTimelinePath();
  }

  Future<void> loadFromConfiguredFolder() async {
    final settings = await _ref.read(locationSettingsProvider.future);
    if (settings.needsReselect) {
      throw const FormatException(
        'Folder access expired. Open Location settings and choose the folder again.',
      );
    }

    final location = settings.pickedLocation;
    if (location == null) {
      throw const FormatException(
        'No Timeline folder selected. Open Location settings from the menu.',
      );
    }

    final match = await findTimelineJson(location);
    if (match == null) {
      throw FormatException(
        'No Timeline.json found in "${settings.displayLabel}".',
      );
    }
    await _importFromUri(match);
  }

  Future<void> loadFromDefaultTimelinePath() async {
    final file = File(_defaultTimelinePath);
    if (!await file.exists()) {
      throw const FormatException(
        'Timeline.json not found at the default path. Use upload to select it manually.',
      );
    }

    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      throw const FormatException('Timeline.json is empty.');
    }

    _setSummaryFromJson(content, fileName: 'Timeline.json');
  }

  Future<void> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final content = await _readFileContent(file);
    final name = file.name;
    if (content == null || content.trim().isEmpty) {
      throw FormatException('Could not read "$name".');
    }

    _setSummaryFromJson(content, fileName: name);
  }

  void clear() => state = const LocationSummary(activities: []);

  Future<void> _importFromUri(TimelineJsonMatch match) async {
    final bytes = await _uriContent.from(match.uri);
    final content = utf8.decode(bytes);
    _setSummaryFromJson(content, fileName: match.fileName);
  }

  void _setSummaryFromJson(String content, {required String fileName}) {
    if (content.trim().isEmpty) {
      throw FormatException('File "$fileName" is empty.');
    }
    final activities = parseTimelineJsonActivities(content);
    if (activities.isEmpty) {
      throw FormatException('No activity segments found in "$fileName".');
    }
    state = LocationSummary(activities: activities, fileName: fileName);
  }

  Future<String?> _readFileContent(PlatformFile file) async {
    if (file.bytes != null) {
      return String.fromCharCodes(file.bytes!);
    }
    if (file.path != null) {
      return File(file.path!).readAsString();
    }
    return null;
  }
}
