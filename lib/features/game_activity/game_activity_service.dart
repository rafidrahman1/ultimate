import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uri_content/uri_content.dart';

import 'package:personal/core/data_cache_service.dart';
import 'package:personal/features/game_activity/game_activity_csv_parser.dart';
import 'package:personal/features/game_activity/game_activity_file_finder.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/core/data_folder_settings_service.dart';
import 'package:dir_picker/dir_picker.dart';

const defaultGameActivityDesktopFolder = r'C:\Users\DOC\Desktop';

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
    final settings = await _ref.read(dataFolderSettingsProvider.future);
    if (settings.hasFolder) {
      await loadFromConfiguredFolder();
      return;
    }

    await loadDefault();
  }

  Future<void> loadFromConfiguredFolder() async {
    final settings = await _ref.read(dataFolderSettingsProvider.future);
    if (settings.needsReselect) {
      throw FormatException(
        'Folder access expired. Open General settings and choose the folder again.',
      );
    }

    final location = settings.pickedLocation;
    if (location == null) {
      throw FormatException(
        'No data folder selected. Open General settings from the menu.',
      );
    }

    final match = await findLatestGameActivityCsv(location);
    if (match == null) {
      throw FormatException(
        'No GameActivity_Export* files found in "${settings.displayLabel}".',
      );
    }

    await _importFromUri(match, location: location);
  }

  Future<void> loadDefault() async {
    final match =
        await findLatestGameActivityCsvOnDisk(defaultGameActivityDesktopFolder);
    if (match == null) {
      throw FormatException(
        'No Game Activity CSV found on Desktop. Import a CSV manually or choose a data folder in General settings.',
      );
    }

    await _importFromUri(match);
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

  Future<void> _importFromUri(
    GameActivityCsvMatch match, {
    PickedLocation? location,
  }) async {
    final content = await _readCsvMatchContent(match);
    if (content.trim().isEmpty) {
      throw FormatException('File "${match.fileName}" is empty');
    }

    _applyContent(content, fileName: match.fileName);
    await _deleteStaleExports(match, location: location);
  }

  Future<void> _deleteStaleExports(
    GameActivityCsvMatch match, {
    PickedLocation? location,
  }) async {
    if (location != null) {
      await deleteStaleGameActivityExportsFromLocation(
        location,
        keepFileName: match.fileName,
      );
      return;
    }

    final filePath = match.filePath;
    if (filePath != null) {
      await deleteStaleGameActivityExportsOnDisk(
        p.dirname(filePath),
        keepFileName: match.fileName,
      );
      return;
    }

    if (match.uri.scheme == 'file') {
      await deleteStaleGameActivityExportsOnDisk(
        p.dirname(match.uri.toFilePath()),
        keepFileName: match.fileName,
      );
    }
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
