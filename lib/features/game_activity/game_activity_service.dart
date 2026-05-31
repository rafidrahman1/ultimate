import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uri_content/uri_content.dart';

import '../../core/data_cache_service.dart';
import 'game_activity_csv_parser.dart';
import 'game_activity_file_finder.dart';
import 'game_activity_session.dart';
import 'game_activity_settings_service.dart';

const defaultGameActivityCsvPath =
    r'C:\Users\DOC\Desktop\GameActivity_Export_2026-05-30_11-06-23.csv';

const bundledGameActivityAsset = 'assets/game_activity_export.csv';

final gameActivitySummaryProvider =
    StateNotifierProvider<GameActivityNotifier, GameActivitySummary>((ref) {
  final notifier = GameActivityNotifier(ref);
  unawaited(notifier.restoreFromCache());
  return notifier;
});

class GameActivityNotifier extends StateNotifier<GameActivitySummary> {
  GameActivityNotifier(this._ref) : super(const GameActivitySummary(sessions: []));

  final Ref _ref;
  final _uriContent = UriContent();
  bool _cacheRestored = false;

  Future<void> restoreFromCache() async {
    if (_cacheRestored) return;
    _cacheRestored = true;
    final cached = await DataCacheService.instance.loadGameActivity();
    if (cached != null && cached.sessions.isNotEmpty) {
      state = cached;
    }
  }

  void _commit(GameActivitySummary summary) {
    state = summary;
    if (summary.sessions.isNotEmpty) {
      unawaited(DataCacheService.instance.saveGameActivity(summary));
    }
  }

  Future<void> loadAuto() async {
    final settings = await _ref.read(gameActivitySettingsProvider.future);
    if (settings.hasFolder && !settings.needsReselect) {
      try {
        await loadFromConfiguredFolder();
        return;
      } catch (_) {
        // Fall through to bundled/default export when folder load fails.
      }
    }
    await loadDefault();
  }

  Future<void> loadFromConfiguredFolder() async {
    final settings = await _ref.read(gameActivitySettingsProvider.future);
    if (settings.needsReselect) {
      throw FormatException(
        'Folder access expired. Open Game Activity settings and choose the folder again.',
      );
    }

    final location = settings.pickedLocation;
    if (location == null) {
      throw FormatException(
        'No Game Activity folder selected. Open Game Activity settings from the menu.',
      );
    }

    final match = await findLatestGameActivityCsv(location);
    if (match == null) {
      throw FormatException(
        'No GameActivity_Export_*.csv found in "${settings.displayLabel}".',
      );
    }

    await _importFromUri(match);
  }

  Future<void> loadDefault() async {
    final desktopFile = File(defaultGameActivityCsvPath);
    if (await desktopFile.exists()) {
      await _loadFromPath(desktopFile.path);
      return;
    }

    final content = await rootBundle.loadString(bundledGameActivityAsset);
    _applyContent(content, fileName: 'game_activity_export.csv');
  }

  Future<void> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final name = file.name;

    final content = await _readFileContent(file);
    if (content == null || content.trim().isEmpty) {
      throw FormatException('Could not read "$name"');
    }

    _applyContent(content, fileName: name);
  }

  Future<void> _importFromUri(GameActivityCsvMatch match) async {
    final content = await _readCsvMatchContent(match);
    if (content.trim().isEmpty) {
      throw FormatException('File "${match.fileName}" is empty');
    }

    _applyContent(content, fileName: match.fileName);
  }

  Future<String> _readCsvMatchContent(GameActivityCsvMatch match) async {
    final filePath = match.filePath;
    if (filePath != null) {
      final file = File(filePath);
      if (await file.exists()) {
        return file.readAsString();
      }
    }

    if (match.uri.scheme == 'file') {
      try {
        return File(match.uri.toFilePath()).readAsString();
      } catch (_) {
        // Fall through to URI content reader.
      }
    }

    final bytes = await _uriContent.from(match.uri);
    return utf8.decode(bytes);
  }

  Future<void> _loadFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FormatException('File not found: "$path"');
    }

    final content = await file.readAsString();
    _applyContent(content, fileName: file.uri.pathSegments.last);
  }

  void _applyContent(String content, {required String fileName}) {
    if (content.trim().isEmpty) {
      throw FormatException('File "$fileName" is empty');
    }

    final sessions = parseGameActivityCsv(content);
    if (sessions.isEmpty) {
      throw FormatException('No game sessions found in "$fileName"');
    }

    _commit(GameActivitySummary(sessions: sessions, fileName: fileName));
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

  void clear() {
    state = const GameActivitySummary(sessions: []);
    unawaited(DataCacheService.instance.clearGameActivity());
  }
}
