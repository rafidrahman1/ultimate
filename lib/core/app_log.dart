import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Warnings go to the debug console and to a small rolling file in the
/// app-support directory, so a failure on a release build still leaves a
/// trace. The file never leaves the device.
abstract final class AppLog {
  /// Once the file passes this size the older half is dropped.
  static const maxBytes = 256 * 1024;

  static const _fileName = 'app_log.txt';

  /// Where the log file lives; tests point this at a temp directory.
  @visibleForTesting
  static Future<Directory> Function()? directoryOverride;

  static Future<void> _pending = Future<void>.value();

  static void warn(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
    final line = '${clock.now().toIso8601String()} $message\n';
    _pending = _pending.then((_) => _append(line));
  }

  /// The stored log, oldest line first. Empty when nothing was logged.
  static Future<String> read() async {
    await _pending;
    try {
      final file = await _file();
      return await file.exists() ? await file.readAsString() : '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> clear() async {
    await _pending;
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Nothing useful to do: the log is best-effort.
    }
  }

  static Future<File> _file() async {
    final override = directoryOverride;
    final dir = override != null
        ? await override()
        : await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<void> _append(String line) async {
    try {
      final file = await _file();
      if (await file.exists() && await file.length() > maxBytes) {
        final text = await file.readAsString();
        final half = text.substring(text.length ~/ 2);
        final firstBreak = half.indexOf('\n');
        await file.writeAsString(half.substring(firstBreak + 1));
      }
      await file.writeAsString(line, mode: FileMode.append);
    } catch (_) {
      // No storage (tests, early startup): the console line is all we get.
    }
  }
}
