import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/core/app_log.dart';
import 'package:personal/features/analysis/analysis_reports_storage.dart';

const backupFileName = 'personal-backup.json';
const _backupFormat = 1;

/// Preference keys that are device-specific or rebuilt from source files.
bool _isExcludedFromBackup(String key) =>
    key.endsWith('_folder_uri_v1') ||
    key.endsWith('_folder_label_v1') ||
    key.endsWith('_folder_path_v1') ||
    key.startsWith('data_cache_') ||
    key == legacyAnalysisResultsStorageKey;

class BackupInfo {
  const BackupInfo({required this.createdAt, required this.entryCount});

  final DateTime createdAt;
  final int entryCount;
}

/// Writes settings and checklist progress to the data folder next to the
/// reports, so a reinstall loses nothing but API keys (kept in the Keystore).
class BackupService {
  const BackupService({AnalysisReportsStorage? storage}) : _storage = storage;

  final AnalysisReportsStorage? _storage;

  AnalysisReportsStorage get _reports =>
      _storage ?? AnalysisReportsStorage.instance;

  Future<File> _file() async {
    final dir = await _reports.reportsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$backupFileName');
  }

  Future<BackupInfo> backUp() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = <String, Object>{};
    for (final key in prefs.getKeys()) {
      if (_isExcludedFromBackup(key)) continue;
      final value = prefs.get(key);
      if (value != null) entries[key] = value;
    }
    final createdAt = DateTime.now();
    final payload = {
      'format': _backupFormat,
      'createdAt': createdAt.toIso8601String(),
      'prefs': entries,
    };
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(payload), flush: true);
    await temp.rename(file.path);
    return BackupInfo(createdAt: createdAt, entryCount: entries.length);
  }

  /// Backup metadata, or null when no readable backup exists.
  Future<BackupInfo?> peek() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final map = _decode(await file.readAsString());
      final createdAt = DateTime.tryParse(map['createdAt'] as String? ?? '');
      if (createdAt == null) return null;
      return BackupInfo(
        createdAt: createdAt,
        entryCount: (map['prefs'] as Map).length,
      );
    } catch (error) {
      AppLog.warn('Could not read backup: $error');
      return null;
    }
  }

  /// Applies the backup over current preferences. Returns restored entries.
  Future<int> restore() async {
    final file = await _file();
    final map = _decode(await file.readAsString());
    final saved = (map['prefs'] as Map).cast<String, Object?>();
    final prefs = await SharedPreferences.getInstance();
    var restored = 0;
    for (final entry in saved.entries) {
      final key = entry.key;
      final value = entry.value;
      if (_isExcludedFromBackup(key)) continue;
      switch (value) {
        case final String v:
          await prefs.setString(key, v);
        case final bool v:
          await prefs.setBool(key, v);
        case final int v:
          await prefs.setInt(key, v);
        case final double v:
          await prefs.setDouble(key, v);
        case final List<dynamic> v:
          await prefs.setStringList(key, v.map((e) => '$e').toList());
        default:
          continue;
      }
      restored++;
    }
    return restored;
  }

  Map<String, dynamic> _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['prefs'] is! Map) {
      throw const FormatException('Not a Personal backup file.');
    }
    return decoded.cast<String, dynamic>();
  }
}
