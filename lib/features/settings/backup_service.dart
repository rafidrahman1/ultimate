import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/data_folder_directory.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const backupFileName = 'personal-backup.json';
const _backupFormat = 1;

/// Preference keys that are device-specific or rebuilt from source files.
bool _isExcludedFromBackup(String key) =>
    key.endsWith('_folder_uri_v1') ||
    key.endsWith('_folder_label_v1') ||
    key.endsWith('_folder_path_v1') ||
    key.startsWith('data_cache_') ||
    key == 'analysis_results_v1';

class BackupInfo {
  const BackupInfo({required this.createdAt, required this.entryCount});

  final DateTime createdAt;
  final int entryCount;
}

/// Writes settings and AI API keys to the data folder, so a reinstall loses
/// nothing. The keys are stored in plain text in the backup file.
class BackupService {
  const BackupService();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<Map<String, String>> _readSecrets() async {
    final secrets = <String, String>{};
    for (final key in aiApiKeyStorageKeys) {
      try {
        final value = await _secureStorage.read(key: key);
        if (value != null && value.isNotEmpty) secrets[key] = value;
      } catch (error) {
        AppLog.warn('Could not read $key for backup: $error');
      }
    }
    return secrets;
  }

  Future<File> _file() async {
    final dir = await DataFolderDirectory.instance.resolve();
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
    final secrets = await _readSecrets();
    final createdAt = DateTime.now();
    final payload = {
      'format': _backupFormat,
      'createdAt': createdAt.toIso8601String(),
      'prefs': entries,
      'secrets': secrets,
    };
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(payload), flush: true);
    await temp.rename(file.path);
    return BackupInfo(
      createdAt: createdAt,
      entryCount: entries.length + secrets.length,
    );
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
        entryCount:
            (map['prefs'] as Map).length +
            ((map['secrets'] as Map?)?.length ?? 0),
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
    final secrets = map['secrets'];
    if (secrets is Map) {
      for (final key in aiApiKeyStorageKeys) {
        final value = secrets[key];
        if (value is! String || value.isEmpty) continue;
        try {
          await _secureStorage.write(key: key, value: value);
          restored++;
        } catch (error) {
          AppLog.warn('Could not restore $key: $error');
        }
      }
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
