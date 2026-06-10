import 'package:dir_picker/dir_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/core/app_log.dart';

const appDataFolderUriKey = 'app_data_folder_uri_v1';
const appDataFolderLabelKey = 'app_data_folder_label_v1';

const _legacyUriKeys = <String>[
  'analysis_reports_folder_uri_v1',
  'expenses_cashew_folder_uri_v1',
  'location_timeline_folder_uri_v1',
  'game_activity_export_folder_uri_v1',
];

const _legacyLabelKeys = <String>[
  'analysis_reports_folder_label_v1',
  'expenses_cashew_folder_label_v1',
  'location_timeline_folder_label_v1',
  'game_activity_export_folder_label_v1',
];

const _legacyPathKeys = <String>[
  'expenses_cashew_folder_path_v1',
  'location_timeline_folder_path_v1',
  'game_activity_export_folder_path_v1',
];

final dataFolderSettingsProvider =
    AsyncNotifierProvider<DataFolderSettingsNotifier, DataFolderSettings>(
  DataFolderSettingsNotifier.new,
);

class DataFolderSettings {
  const DataFolderSettings({
    this.folderUri,
    this.folderLabel,
    this.needsReselect = false,
  });

  final String? folderUri;
  final String? folderLabel;
  final bool needsReselect;

  bool get hasFolder => folderUri != null && folderUri!.trim().isNotEmpty;

  PickedLocation? get pickedLocation {
    if (!hasFolder) return null;
    return IOPickedLocation(Uri.parse(folderUri!));
  }

  String get displayLabel =>
      folderLabel ??
      folderUri ??
      'Pick the folder that contains your exports and reports.';
}

class DataFolderSettingsNotifier extends AsyncNotifier<DataFolderSettings> {
  static DataFolderSettings _memoryFallback = const DataFolderSettings();

  @override
  Future<DataFolderSettings> build() async {
    final prefs = await _safePrefs();
    if (prefs == null) return _memoryFallback;

    final uri = prefs.getString(appDataFolderUriKey)?.trim();
    final label = prefs.getString(appDataFolderLabelKey)?.trim();
    if (uri != null && uri.isNotEmpty) {
      final loaded = DataFolderSettings(
        folderUri: uri,
        folderLabel: label?.isEmpty ?? true ? null : label,
      );
      _memoryFallback = loaded;
      return loaded;
    }

    final migrated = _loadLegacy(prefs);
    if (migrated != null) {
      await _persist(migrated, prefs);
      return migrated;
    }

    return const DataFolderSettings();
  }

  DataFolderSettings? _loadLegacy(SharedPreferences prefs) {
    for (final key in _legacyUriKeys) {
      final uri = prefs.getString(key)?.trim();
      if (uri == null || uri.isEmpty) continue;

      String? label;
      final labelIndex = _legacyUriKeys.indexOf(key);
      if (labelIndex >= 0 && labelIndex < _legacyLabelKeys.length) {
        label = prefs.getString(_legacyLabelKeys[labelIndex])?.trim();
      }

      return DataFolderSettings(
        folderUri: uri,
        folderLabel: label?.isEmpty ?? true ? null : label,
      );
    }

    for (final key in _legacyPathKeys) {
      final path = prefs.getString(key)?.trim();
      if (path == null || path.isEmpty) continue;
      return DataFolderSettings(folderLabel: path, needsReselect: true);
    }

    return null;
  }

  Future<void> saveFolder(PickedLocation location) async {
    final uri = location.uri;
    if (uri == null) {
      throw ArgumentError('Picked folder has no URI on this platform.');
    }

    final next = DataFolderSettings(
      folderUri: uri.toString(),
      folderLabel: _labelFromUri(uri),
    );
    await _persist(next);
  }

  Future<void> clearFolder() => _persist(const DataFolderSettings());

  Future<void> _persist(
    DataFolderSettings next, [
    SharedPreferences? prefsOverride,
  ]) async {
    _memoryFallback = next;
    final prefs = prefsOverride ?? await _safePrefs();
    if (prefs != null) {
      if (next.folderUri == null) {
        await prefs.remove(appDataFolderUriKey);
        await prefs.remove(appDataFolderLabelKey);
      } else {
        await prefs.setString(appDataFolderUriKey, next.folderUri!);
        if (next.folderLabel == null) {
          await prefs.remove(appDataFolderLabelKey);
        } else {
          await prefs.setString(appDataFolderLabelKey, next.folderLabel!);
        }
      }
      await _removeLegacyKeys(prefs);
    } else {
      AppLog.warn(
        'SharedPreferences unavailable. Using in-memory data folder settings.',
      );
    }
    state = AsyncData(next);
  }

  Future<void> _removeLegacyKeys(SharedPreferences prefs) async {
    for (final key in [
      ..._legacyUriKeys,
      ..._legacyLabelKeys,
      ..._legacyPathKeys,
    ]) {
      await prefs.remove(key);
    }
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
      AppLog.warn('SharedPreferences channel error: $error');
      return null;
    } catch (error) {
      AppLog.warn('SharedPreferences init failed: $error');
      return null;
    }
  }
}
