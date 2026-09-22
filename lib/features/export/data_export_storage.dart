import 'dart:io';

import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/features/results/results_folder_path.dart';

const dataExportFilePrefix = 'personal-data-export-';
const dataExportFileSuffix = '.md';

const missingExportFolderMessage =
    'Choose a data folder in General settings from the menu before exporting.';

/// Writes personal-data export files into the user-selected data folder,
/// following the same folder resolution and permission handling as
/// [AnalysisReportsStorage].
class DataExportStorage {
  DataExportStorage._({Directory? directoryOverride})
    : _directoryOverride = directoryOverride;

  static final DataExportStorage instance = DataExportStorage._();

  factory DataExportStorage.forDirectory(Directory directory) {
    return DataExportStorage._(directoryOverride: directory);
  }

  final Directory? _directoryOverride;
  Directory? _cachedDirectory;

  /// Resolves the configured save folder. Never creates folders automatically.
  Future<Directory> exportDirectory() async {
    final override = _directoryOverride;
    if (override != null) {
      if (!await override.exists()) {
        throw StateError('Export save folder does not exist: ${override.path}');
      }
      return override;
    }

    if (_cachedDirectory != null) {
      if (await _cachedDirectory!.exists()) return _cachedDirectory!;
      _cachedDirectory = null;
    }

    final configured = await _configuredDirectoryFromSettings();
    if (configured == null) {
      throw StateError(missingExportFolderMessage);
    }
    if (!await configured.exists()) {
      throw StateError(
        'Export save folder does not exist: ${configured.path}. '
        'Re-select the folder in General settings.',
      );
    }

    await _ensureStorageAccess();
    await _verifyWritable(configured);
    _cachedDirectory = configured;
    return configured;
  }

  Future<File> save(String markdown, {required DateTime generatedAt}) async {
    final dir = await exportDirectory();
    final timestamp = DateFormat('yyyyMMdd-HHmmss').format(generatedAt);
    final file = File(
      '${dir.path}${Platform.pathSeparator}'
      '$dataExportFilePrefix$timestamp$dataExportFileSuffix',
    );
    await file.writeAsString(markdown);
    return file;
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
      'Storage permission is required to save the export in the selected '
      'folder. Grant storage or "All files access" in app settings.',
    );
  }

  Future<Directory?> _configuredDirectoryFromSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final uriString = prefs.getString(analysisReportsFolderUriKey)?.trim();
    if (uriString == null || uriString.isEmpty) return null;
    return directoryFromReportsFolderUri(uriString);
  }

  Future<void> _verifyWritable(Directory directory) async {
    final probe = File(
      '${directory.path}${Platform.pathSeparator}.data_export_write_probe',
    );
    await probe.writeAsString('ok');
    await probe.delete();
  }
}
