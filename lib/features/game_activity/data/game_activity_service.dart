import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/auth/google_drive_client.dart';
import 'package:personal/features/game_activity/data/game_activity_cache.dart';
import 'package:personal/features/game_activity/data/game_activity_csv_parser.dart';
import 'package:personal/features/game_activity/data/game_activity_file_finder.dart';
import 'package:personal/features/game_activity/data/game_activity_session.dart';

final gameActivitySummaryProvider =
    StateNotifierProvider<GameActivityNotifier, GameActivitySummary>((ref) {
      final notifier = GameActivityNotifier(ref);
      unawaited(notifier.restoreFromCache());
      return notifier;
    });

class GameActivityNotifier extends StateNotifier<GameActivitySummary> {
  GameActivityNotifier(Ref ref)
    : _driveClient = GoogleDriveClient(
        accountService: ref.read(googleAccountServiceProvider),
      ),
      super(const GameActivitySummary(sessions: []));

  final GoogleDriveClient _driveClient;
  Future<void>? _restoreFuture;

  /// Idempotent and safe to await from multiple callers: they all resolve
  /// once the same underlying cache read completes, so a caller that awaits
  /// this can rely on `state` reflecting the cache (if any) afterwards.
  Future<void> restoreFromCache() => _restoreFuture ??= _restoreFromCache();

  Future<void> _restoreFromCache() async {
    final cached = await GameActivityCache.load();
    if (cached != null && cached.sessions.isNotEmpty) {
      state = cached;
    }
  }

  void _commit(GameActivitySummary summary) {
    state = summary;
    if (summary.sessions.isNotEmpty) {
      unawaited(GameActivityCache.save(summary));
    }
  }

  /// Loads the newest GameActivity_Export* CSV from the Google Drive
  /// "Timeline" folder.
  Future<void> loadAuto({bool interactiveSignIn = false}) async {
    try {
      final result = await _driveClient.fetchNewestFileInFolder(
        folderName: gameActivityDriveFolderName,
        nameQuery: "name contains '$gameActivityExportPrefix'",
        fileNameMatches: isGameActivityExportFileName,
        fileDescription: '$gameActivityExportPrefix* files',
        timestampOf: gameActivityTimestampFromFileName,
        interactiveSignIn: interactiveSignIn,
      );
      await _applyContent(result.content, fileName: result.fileName);
    } on FormatException {
      if (!interactiveSignIn && state.sessions.isNotEmpty) return;
      rethrow;
    }
  }

  Future<void> importFromPicker() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (file == null) return;

    final name = file.name;

    final content = await _readFileContent(file);
    if (content == null || content.trim().isEmpty) {
      throw FormatException('Could not read "$name"');
    }

    await _applyContent(content, fileName: name);
  }

  Future<void> _applyContent(String content, {required String fileName}) async {
    if (content.trim().isEmpty) {
      throw FormatException('File "$fileName" is empty');
    }

    final sessions = await Isolate.run(() => parseGameActivityCsv(content));
    if (sessions.isEmpty) {
      throw FormatException('No game sessions found in "$fileName"');
    }

    _commit(GameActivitySummary(sessions: sessions, fileName: fileName));
  }

  Future<String?> _readFileContent(PlatformFile file) async {
    // Decode as UTF-8 so game titles outside ASCII survive.
    return utf8.decode(await file.readAsBytes(), allowMalformed: true);
  }

  void clear() {
    state = const GameActivitySummary(sessions: []);
    unawaited(GameActivityCache.clear());
  }
}
