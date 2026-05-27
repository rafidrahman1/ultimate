import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'timeline_activity.dart';

const _defaultTimelinePath =
    r"c:\Users\DOC\CrossDevice\Rafid's S22\storage\Download\Timeline\Timeline.json";

final locationSummaryProvider =
    StateNotifierProvider<LocationSummaryNotifier, LocationSummary>((ref) {
      return LocationSummaryNotifier();
    });

class LocationSummaryNotifier extends StateNotifier<LocationSummary> {
  LocationSummaryNotifier() : super(const LocationSummary(activities: []));

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

    final activities = parseTimelineJsonActivities(content);
    if (activities.isEmpty) {
      throw const FormatException(
        'No activity segments found in Timeline.json.',
      );
    }

    state = LocationSummary(activities: activities, fileName: 'Timeline.json');
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

    final activities = parseTimelineJsonActivities(content);
    if (activities.isEmpty) {
      throw FormatException('No activity segments found in "$name".');
    }

    state = LocationSummary(activities: activities, fileName: name);
  }

  void clear() => state = const LocationSummary(activities: []);

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
