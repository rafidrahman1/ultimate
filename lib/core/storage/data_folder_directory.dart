import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:personal/core/storage/data_folder_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const missingDataFolderMessage =
    'Choose a data folder in General settings from the menu first.';

/// Turns the saved data-folder URI into a real directory.
Directory? directoryFromDataFolderUri(String uriString) {
  final uri = Uri.tryParse(uriString.trim());
  if (uri == null) return null;

  if (uri.scheme == 'file') {
    return Directory(uri.toFilePath());
  }

  if (uri.scheme == 'content' && uri.pathSegments.contains('tree')) {
    final treeId = Uri.decodeComponent(uri.pathSegments.last);
    final separatorIndex = treeId.indexOf(':');
    if (separatorIndex >= 0 && separatorIndex < treeId.length - 1) {
      final relativePath = treeId.substring(separatorIndex + 1);
      if (relativePath.isNotEmpty) {
        return Directory(
          '/storage/emulated/0${Platform.pathSeparator}'
          '${relativePath.replaceAll('/', Platform.pathSeparator)}',
        );
      }
    }
  }

  return null;
}

/// Resolves the user-selected data folder to a writable directory.
class DataFolderDirectory {
  DataFolderDirectory._();

  static final DataFolderDirectory instance = DataFolderDirectory._();

  Directory? _cachedDirectory;

  void invalidateCache() => _cachedDirectory = null;

  /// Resolves the configured folder. Never creates folders automatically.
  Future<Directory> resolve() async {
    final cached = _cachedDirectory;
    if (cached != null) {
      if (await cached.exists()) return cached;
      _cachedDirectory = null;
    }

    final configured = await _configuredDirectoryFromSettings();
    if (configured == null) {
      throw StateError(missingDataFolderMessage);
    }
    if (!await configured.exists()) {
      throw StateError(
        'Data folder does not exist: ${configured.path}. '
        'Re-select the folder in General settings.',
      );
    }

    await _ensureStorageAccess();
    await _verifyWritable(configured);
    _cachedDirectory = configured;
    return configured;
  }

  Future<void> _ensureStorageAccess() async {
    if (!Platform.isAndroid) return;

    if (await Permission.manageExternalStorage.isGranted) return;
    if (await Permission.storage.isGranted) return;

    final storageResult = await Permission.storage.request();
    if (storageResult.isGranted) return;
    if (await Permission.manageExternalStorage.isGranted) return;

    final manageResult = await Permission.manageExternalStorage.request();
    if (manageResult.isGranted) return;

    throw StateError(
      'Storage permission is required to save files in the selected folder. '
      'Grant storage or "All files access" in app settings.',
    );
  }

  Future<Directory?> _configuredDirectoryFromSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final uriString = prefs.getString(appDataFolderUriKey)?.trim();
    if (uriString == null || uriString.isEmpty) return null;
    return directoryFromDataFolderUri(uriString);
  }

  Future<void> _verifyWritable(Directory directory) async {
    final probe = File(
      '${directory.path}${Platform.pathSeparator}.data_folder_write_probe',
    );
    await probe.writeAsString('ok');
    await probe.delete();
  }
}
