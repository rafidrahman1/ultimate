import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uri_content/uri_content.dart';

import 'package:personal/core/data_cache_service.dart';
import 'package:personal/core/data_folder_settings_service.dart';
import 'package:personal/features/location/timeline_file_finder.dart';
import 'package:personal/features/location/timeline_activity.dart';

const _defaultTimelinePath =
    r"c:\Users\DOC\CrossDevice\Rafid's S22\storage\Download\Timeline\Timeline.json";

final locationSummaryProvider =
    StateNotifierProvider<LocationSummaryNotifier, LocationSummary>((ref) {
      final notifier = LocationSummaryNotifier(ref);
      unawaited(notifier.restoreFromCache());
      return notifier;
    });

class LocationSummaryNotifier extends StateNotifier<LocationSummary> {
  LocationSummaryNotifier(this._ref)
    : super(const LocationSummary(activities: [], placeVisits: []));

  final Ref _ref;
  final _uriContent = UriContent();
  bool _cacheRestored = false;

  Future<void> restoreFromCache() async {
    if (_cacheRestored) return;
    _cacheRestored = true;
    final cached = await DataCacheService.instance.loadLocation();
    if (cached != null && cached.activities.isNotEmpty) {
      state = cached;
    }
  }

  void _commit(LocationSummary summary) {
    state = summary;
    if (summary.hasAnyData) {
      unawaited(DataCacheService.instance.saveLocation(summary));
    }
  }

  Future<void> loadAuto() async {
    final settings = await _ref.read(dataFolderSettingsProvider.future);
    if (settings.hasFolder && !settings.needsReselect) {
      await loadFromConfiguredFolder();
      return;
    }
    await loadFromDefaultTimelinePath();
  }

  Future<void> loadFromConfiguredFolder() async {
    final settings = await _ref.read(dataFolderSettingsProvider.future);
    if (settings.needsReselect) {
      throw const FormatException(
        'Folder access expired. Open General settings and choose the folder again.',
      );
    }

    final location = settings.pickedLocation;
    if (location == null) {
      throw const FormatException(
        'No data folder selected. Open General settings from the menu.',
      );
    }

    final match = await findTimelineJson(location);
    if (match == null) {
      throw FormatException(
        'No Timeline export found in "${settings.displayLabel}".',
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

  void clear() {
    state = const LocationSummary(activities: [], placeVisits: []);
    unawaited(DataCacheService.instance.clearLocation());
  }

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
    final placeVisits = parseTimelineJsonPlaceVisits(content);
    if (activities.isEmpty && placeVisits.isEmpty) {
      throw FormatException(
        'No activity or place-visit segments found in "$fileName".',
      );
    }
    _commit(
      LocationSummary(
        activities: activities,
        placeVisits: placeVisits,
        fileName: fileName,
      ),
    );
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
