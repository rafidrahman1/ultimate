import 'dart:convert';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/features/results/results_folder_path.dart';
import 'package:personal/core/app_log.dart';

const legacyAnalysisResultsStorageKey = 'analysis_results_v1';
const analysisReportFilePrefix = 'analysis-report-';
const analysisReportFileSuffix = '.json';

const missingReportsFolderMessage =
    'Choose a report save folder in Results settings from the menu before analyzing.';

/// Persists analysis reports as JSON files in a user-selected folder.
class AnalysisReportsStorage {
  AnalysisReportsStorage._({Directory? directoryOverride})
      : _directoryOverride = directoryOverride;

  static final AnalysisReportsStorage instance = AnalysisReportsStorage._();

  factory AnalysisReportsStorage.forDirectory(Directory directory) {
    return AnalysisReportsStorage._(directoryOverride: directory);
  }

  final Directory? _directoryOverride;
  Directory? _cachedDirectory;
  bool _legacyMigrated = false;

  void invalidateCache() => _cachedDirectory = null;

  Future<bool> hasConfiguredFolder() async {
    if (_directoryOverride != null) return true;

    final prefs = await SharedPreferences.getInstance();
    final uriString = prefs.getString(analysisReportsFolderUriKey)?.trim();
    return uriString != null && uriString.isNotEmpty;
  }

  /// Resolves the configured save folder. Never creates folders automatically.
  Future<Directory> reportsDirectory() async {
    final override = _directoryOverride;
    if (override != null) {
      if (!await override.exists()) {
        throw StateError(
          'Report save folder does not exist: ${override.path}',
        );
      }
      return override;
    }

    if (_cachedDirectory != null) {
      if (await _cachedDirectory!.exists()) return _cachedDirectory!;
      _cachedDirectory = null;
    }

    final configured = await _configuredDirectoryFromSettings();
    if (configured == null) {
      throw StateError(missingReportsFolderMessage);
    }
    if (!await configured.exists()) {
      throw StateError(
        'Report save folder does not exist: ${configured.path}. '
        'Re-select the folder in Results settings.',
      );
    }

    await _ensureStorageAccess();
    await _verifyWritable(configured);
    _cachedDirectory = configured;
    return configured;
  }

  Future<List<Map<String, dynamic>>> loadAll() async {
    if (!await hasConfiguredFolder()) return [];

    try {
      await _migrateLegacySharedPreferencesIfNeeded();

      final dir = await reportsDirectory();
      final results = <Map<String, dynamic>>[];

      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = _baseName(entity.path);
        if (!_isReportFileName(name)) continue;

        try {
          final raw = await entity.readAsString();
          if (raw.trim().isEmpty) continue;
          final decoded = jsonDecode(raw);
          if (decoded is! Map) continue;
          results.add(decoded.cast<String, dynamic>());
        } catch (error) {
          AppLog.warn('Skipping invalid analysis report "$name": $error');
        }
      }

      return results;
    } catch (error) {
      AppLog.warn('Could not load analysis reports: $error');
      return [];
    }
  }

  Future<void> save(Map<String, dynamic> json) async {
    final id = json['id'] as String? ?? '';
    if (id.isEmpty) {
      throw ArgumentError('Analysis report JSON must include a non-empty id.');
    }

    final dir = await reportsDirectory();
    final file = File(_reportFilePath(dir, id));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  Future<void> delete(String id) async {
    if (id.isEmpty) return;
    if (!await hasConfiguredFolder()) return;

    final dir = await reportsDirectory();
    final file = File(_reportFilePath(dir, id));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> clearAll() async {
    if (!await hasConfiguredFolder()) return;

    final dir = await reportsDirectory();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (_isReportFileName(_baseName(entity.path))) {
        await entity.delete();
      }
    }
  }

  Future<void> _migrateLegacySharedPreferencesIfNeeded() async {
    if (_legacyMigrated) return;
    _legacyMigrated = true;
    if (!await hasConfiguredFolder()) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(legacyAnalysisResultsStorageKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final item in decoded.whereType<Map>()) {
        await save(item.cast<String, dynamic>());
      }
      await prefs.remove(legacyAnalysisResultsStorageKey);
    } catch (error) {
      AppLog.warn(
        'Failed to migrate analysis results from SharedPreferences: $error',
      );
    }
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
      'Storage permission is required to save reports in the selected folder. '
      'Grant storage or "All files access" in app settings.',
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
      '${directory.path}${Platform.pathSeparator}.analysis_report_write_probe',
    );
    await probe.writeAsString('ok');
    await probe.delete();
  }

  String _reportFilePath(Directory dir, String id) {
    return '${dir.path}${Platform.pathSeparator}$analysisReportFilePrefix$id$analysisReportFileSuffix';
  }

  bool _isReportFileName(String name) {
    return name.startsWith(analysisReportFilePrefix) &&
        name.endsWith(analysisReportFileSuffix);
  }

  String _baseName(String path) {
    final separator = Platform.pathSeparator;
    final index = path.lastIndexOf(separator);
    return index < 0 ? path : path.substring(index + 1);
  }
}
