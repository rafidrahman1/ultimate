import 'package:flutter/foundation.dart';

abstract final class AppLog {
  static void warn(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
