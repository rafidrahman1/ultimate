import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/core/app_log.dart';

/// [SharedPreferences.getInstance], or null when the platform channel is
/// unavailable (tests, early startup) so callers can fall back to memory.
Future<SharedPreferences?> safePrefs() async {
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
