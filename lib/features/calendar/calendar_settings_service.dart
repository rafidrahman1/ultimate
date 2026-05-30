import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _calendarConnectedEmailKey = 'calendar_connected_email_v1';

final calendarSettingsProvider =
    AsyncNotifierProvider<CalendarSettingsNotifier, CalendarSettings>(
  CalendarSettingsNotifier.new,
);

class CalendarSettings {
  const CalendarSettings({this.connectedEmail});

  final String? connectedEmail;

  bool get isConnected =>
      connectedEmail != null && connectedEmail!.trim().isNotEmpty;

  String get displayLabel =>
      connectedEmail ?? 'Sign in with your Google account to sync events.';
}

class CalendarSettingsNotifier extends AsyncNotifier<CalendarSettings> {
  static CalendarSettings _memoryFallback = const CalendarSettings();

  @override
  Future<CalendarSettings> build() async {
    final prefs = await _safePrefs();
    if (prefs == null) return _memoryFallback;

    final loaded = CalendarSettings(
      connectedEmail: prefs.getString(_calendarConnectedEmailKey)?.trim(),
    );
    _memoryFallback = loaded;
    return loaded;
  }

  Future<void> saveConnectedEmail(String? email) async {
    final trimmed = email?.trim();
    final next = CalendarSettings(
      connectedEmail: trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
    await _persist(next);
  }

  Future<void> clearConnection() => saveConnectedEmail(null);

  Future<void> _persist(CalendarSettings next) async {
    _memoryFallback = next;
    final prefs = await _safePrefs();
    if (prefs != null) {
      if (next.connectedEmail == null) {
        await prefs.remove(_calendarConnectedEmailKey);
      } else {
        await prefs.setString(_calendarConnectedEmailKey, next.connectedEmail!);
      }
    } else {
      debugPrint(
        'SharedPreferences unavailable. Using in-memory calendar settings.',
      );
    }
    state = AsyncData(next);
  }

  Future<SharedPreferences?> _safePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on PlatformException catch (error) {
      debugPrint('SharedPreferences channel error: $error');
      return null;
    } catch (error) {
      debugPrint('SharedPreferences init failed: $error');
      return null;
    }
  }
}
