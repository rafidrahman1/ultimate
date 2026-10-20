import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:motohealth/core/app_log.dart';
import 'package:motohealth/core/storage/prefs.dart';
import 'package:path_provider/path_provider.dart';

/// Atomic, per-key JSON files under the app-support `data_cache/` directory.
///
/// Knows nothing about what is stored; each feature owns the shape of its own
/// entry and its (de)serialization.
class JsonFileCache {
  JsonFileCache._();

  static final JsonFileCache instance = JsonFileCache._();

  /// Where cache files live; tests point this at a temp directory.
  @visibleForTesting
  static Future<Directory> Function()? directoryOverride;

  Directory? _directory;
  final Map<String, Future<void>> _pendingWrites = {};

  /// Forgets in-flight writes; tests use it so one test's writes (made under
  /// its own fake clock) can't block the next test.
  @visibleForTesting
  void resetForTests() => _pendingWrites.clear();

  Future<File> _fileFor(String key) async {
    final override = directoryOverride;
    var dir = override != null ? await override() : _directory;
    if (dir == null) {
      final base = await getApplicationSupportDirectory();
      dir = Directory('${base.path}${Platform.pathSeparator}data_cache');
      _directory = dir;
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$key.json');
  }

  /// Reads a cache entry from its file. Entries written by older builds live
  /// in SharedPreferences; those are moved to a file on first read.
  Future<Map<String, dynamic>?> read(String key) async {
    await _pendingWrites[key];
    final file = await _fileFor(key);
    if (await file.exists()) {
      final decoded = await _decode(key, await file.readAsString());
      if (decoded != null) return decoded;
      return _recoverFromBackup(key, file);
    }

    final prefs = await safePrefs();
    final legacy = prefs?.getString(key);
    if (legacy == null || legacy.isEmpty) return null;
    final decoded = await _decode(key, legacy);
    if (decoded != null) await _writeRaw(key, legacy);
    await prefs!.remove(key);
    return decoded;
  }

  /// The entry is unreadable: keep it aside as `.corrupt` and fall back to the
  /// copy made before the last write, putting that back as the entry.
  Future<Map<String, dynamic>?> _recoverFromBackup(
    String key,
    File file,
  ) async {
    final backup = File('${file.path}.bak');
    try {
      await file.rename('${file.path}.corrupt');
      if (!await backup.exists()) return null;
      final decoded = await _decode(key, await backup.readAsString());
      if (decoded != null) await backup.copy(file.path);
      return decoded;
    } catch (error) {
      AppLog.warn('Could not recover cache entry $key: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _decode(String key, String raw) async {
    if (raw.isEmpty) return null;
    try {
      // Location/expense history can be megabytes; keep it off the UI thread.
      final decoded = await Isolate.run(() => jsonDecode(raw));
      if (decoded is Map<String, dynamic>) return decoded;
      AppLog.warn('Cache entry $key is not a JSON object; clearing it.');
    } catch (error) {
      AppLog.warn('Cache entry $key is corrupt; clearing it: $error');
    }
    return null;
  }

  Future<void> write(String key, Map<String, dynamic> value) async {
    final raw = await Isolate.run(() => jsonEncode(value));
    await _writeRaw(key, raw);
  }

  /// Writes via a temp file + rename so a crash mid-write can't leave a
  /// truncated cache, and serializes writes per key.
  Future<void> _writeRaw(String key, String raw) {
    final previous = _pendingWrites[key] ?? Future<void>.value();
    final next = previous.then((_) async {
      try {
        final file = await _fileFor(key);
        final temp = File('${file.path}.tmp');
        await temp.writeAsString(raw, flush: true);
        if (await file.exists()) await file.copy('${file.path}.bak');
        await temp.rename(file.path);
      } catch (error) {
        AppLog.warn('Failed to write cache entry $key: $error');
      }
    });
    _pendingWrites[key] = next;
    return next;
  }

  Future<void> remove(String key) async {
    await _pendingWrites[key];
    await _deleteQuietly(await _fileFor(key));
    final prefs = await safePrefs();
    await prefs?.remove(key);
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (error) {
      AppLog.warn('Failed to delete cache file ${file.path}: $error');
    }
  }
}
