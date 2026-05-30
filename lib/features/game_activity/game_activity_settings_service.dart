import 'package:dir_picker/dir_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _gameActivityFolderUriKey = 'game_activity_export_folder_uri_v1';
const _gameActivityFolderLabelKey = 'game_activity_export_folder_label_v1';
const _legacyGameActivityFolderPathKey = 'game_activity_export_folder_path_v1';

final gameActivitySettingsProvider =
    AsyncNotifierProvider<GameActivitySettingsNotifier, GameActivitySettings>(
  GameActivitySettingsNotifier.new,
);

class GameActivitySettings {
  const GameActivitySettings({
    this.exportFolderUri,
    this.exportFolderLabel,
    this.needsReselect = false,
  });

  final String? exportFolderUri;
  final String? exportFolderLabel;
  final bool needsReselect;

  bool get hasFolder =>
      exportFolderUri != null && exportFolderUri!.trim().isNotEmpty;

  PickedLocation? get pickedLocation {
    if (!hasFolder) return null;
    return IOPickedLocation(Uri.parse(exportFolderUri!));
  }

  String get displayLabel =>
      exportFolderLabel ??
      exportFolderUri ??
      'Pick the folder that contains your Game Activity CSV exports.';
}

class GameActivitySettingsNotifier extends AsyncNotifier<GameActivitySettings> {
  static GameActivitySettings _memoryFallback = const GameActivitySettings();

  @override
  Future<GameActivitySettings> build() async {
    final prefs = await _safePrefs();
    if (prefs == null) return _memoryFallback;

    final uri = prefs.getString(_gameActivityFolderUriKey)?.trim();
    final label = prefs.getString(_gameActivityFolderLabelKey)?.trim();
    if (uri != null && uri.isNotEmpty) {
      final loaded = GameActivitySettings(
        exportFolderUri: uri,
        exportFolderLabel: label?.isEmpty ?? true ? null : label,
      );
      _memoryFallback = loaded;
      return loaded;
    }

    final legacyPath =
        prefs.getString(_legacyGameActivityFolderPathKey)?.trim();
    if (legacyPath != null && legacyPath.isNotEmpty) {
      final loaded = GameActivitySettings(
        exportFolderLabel: legacyPath,
        needsReselect: true,
      );
      _memoryFallback = loaded;
      return loaded;
    }

    return const GameActivitySettings();
  }

  Future<void> saveFolder(PickedLocation location) async {
    final uri = location.uri;
    if (uri == null) {
      throw ArgumentError('Picked folder has no URI on this platform.');
    }

    final next = GameActivitySettings(
      exportFolderUri: uri.toString(),
      exportFolderLabel: _labelFromUri(uri),
    );
    await _persist(next);
  }

  Future<void> clearFolder() => _persist(const GameActivitySettings());

  Future<void> _persist(GameActivitySettings next) async {
    _memoryFallback = next;
    final prefs = await _safePrefs();
    if (prefs != null) {
      if (next.exportFolderUri == null) {
        await prefs.remove(_gameActivityFolderUriKey);
        await prefs.remove(_gameActivityFolderLabelKey);
        await prefs.remove(_legacyGameActivityFolderPathKey);
      } else {
        await prefs.setString(_gameActivityFolderUriKey, next.exportFolderUri!);
        if (next.exportFolderLabel == null) {
          await prefs.remove(_gameActivityFolderLabelKey);
        } else {
          await prefs.setString(
            _gameActivityFolderLabelKey,
            next.exportFolderLabel!,
          );
        }
        await prefs.remove(_legacyGameActivityFolderPathKey);
      }
    } else {
      debugPrint(
        'SharedPreferences unavailable. Using in-memory game activity settings.',
      );
    }
    state = AsyncData(next);
  }

  String _labelFromUri(Uri uri) {
    if (uri.scheme == 'file') {
      return uri.toFilePath();
    }

    final encodedPath = uri.pathSegments.isEmpty ? null : uri.pathSegments.last;
    if (encodedPath == null) return uri.toString();

    final decoded = Uri.decodeComponent(encodedPath);
    final colonIndex = decoded.indexOf(':');
    if (colonIndex >= 0 && colonIndex < decoded.length - 1) {
      return decoded.substring(colonIndex + 1);
    }
    return decoded;
  }

  Future<SharedPreferences?> _safePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on PlatformException catch (error) {
      debugPrint('SharedPreferences channel error: $error');
      return null;
    } catch (error) {
      debugPrint('SharedPreferences init failed: $error');
      return null;
    }
  }
}
