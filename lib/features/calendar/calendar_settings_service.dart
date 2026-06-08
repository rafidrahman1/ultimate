import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal/core/app_log.dart';

const _calendarConnectedEmailKey = 'calendar_connected_email_v1';
const _calendarConnectedPhotoUrlKey = 'calendar_connected_photo_url_v1';
const _calendarConnectedDisplayNameKey = 'calendar_connected_display_name_v1';

final calendarSettingsProvider =
    AsyncNotifierProvider<CalendarSettingsNotifier, CalendarSettings>(
  CalendarSettingsNotifier.new,
);

class CalendarSettings {
  const CalendarSettings({
    this.connectedEmail,
    this.connectedPhotoUrl,
    this.connectedDisplayName,
  });

  final String? connectedEmail;
  final String? connectedPhotoUrl;
  final String? connectedDisplayName;

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
      connectedPhotoUrl: prefs.getString(_calendarConnectedPhotoUrlKey)?.trim(),
      connectedDisplayName:
          prefs.getString(_calendarConnectedDisplayNameKey)?.trim(),
    );
    _memoryFallback = loaded;
    return loaded;
  }

  Future<void> saveConnectedEmail(String? email) async {
    await saveConnection(email: email);
  }

  Future<void> saveConnection({
    String? email,
    String? photoUrl,
    String? displayName,
  }) async {
    final current = state.valueOrNull ?? _memoryFallback;
    final trimmed = email?.trim();
    final trimmedPhoto = photoUrl?.trim();
    final trimmedDisplayName = displayName?.trim();
    final disconnecting = trimmed == null || trimmed.isEmpty;
    final next = CalendarSettings(
      connectedEmail: disconnecting ? null : trimmed,
      connectedPhotoUrl: disconnecting
          ? null
          : trimmedPhoto == null || trimmedPhoto.isEmpty
              ? current.connectedPhotoUrl
              : trimmedPhoto,
      connectedDisplayName: disconnecting
          ? null
          : trimmedDisplayName == null || trimmedDisplayName.isEmpty
              ? current.connectedDisplayName
              : trimmedDisplayName,
    );
    await _persist(next);
  }

  Future<void> clearConnection() => saveConnection(email: null, photoUrl: null);

  Future<void> _persist(CalendarSettings next) async {
    _memoryFallback = next;
    final prefs = await _safePrefs();
    if (prefs != null) {
      if (next.connectedEmail == null) {
        await prefs.remove(_calendarConnectedEmailKey);
      } else {
        await prefs.setString(_calendarConnectedEmailKey, next.connectedEmail!);
      }
      if (next.connectedPhotoUrl == null) {
        await prefs.remove(_calendarConnectedPhotoUrlKey);
      } else {
        await prefs.setString(
          _calendarConnectedPhotoUrlKey,
          next.connectedPhotoUrl!,
        );
      }
      if (next.connectedDisplayName == null) {
        await prefs.remove(_calendarConnectedDisplayNameKey);
      } else {
        await prefs.setString(
          _calendarConnectedDisplayNameKey,
          next.connectedDisplayName!,
        );
      }
    } else {
      AppLog.warn(
        'SharedPreferences unavailable. Using in-memory calendar settings.',
      );
    }
    state = AsyncData(next);
  }

  Future<SharedPreferences?> _safePrefs() async {
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
}
