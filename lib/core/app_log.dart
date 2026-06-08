import 'package:flutter/foundation.dart';

/// Lightweight diagnostic logger that only emits in debug builds.
///
/// Release builds stay silent, keeping production output clean while still
/// surfacing recoverable failures (cache misses, storage fallbacks) during
/// development.
abstract final class AppLog {
  static void warn(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
