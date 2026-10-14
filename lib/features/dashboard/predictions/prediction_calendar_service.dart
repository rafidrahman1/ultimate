import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/dashboard/predictions/prediction_cards.dart';

const _enabledKey = 'prediction_calendar_enabled_v1';
const _syncedKey = 'prediction_calendar_synced_v1';

/// Puts dated predictions on the user's primary Google Calendar as all-day
/// events, and keeps them current as the predictions move.
///
/// When a new calculation changes a prediction, its old event is deleted and
/// a fresh one created. Predictions that disappear (switched off, or no
/// longer dated) have their event removed; overdue ones are left alone as a
/// record.
class PredictionCalendarService {
  PredictionCalendarService._();

  /// Keys that are not one-off dates: the commute repeats every working day.
  static const _skipKeys = {'commute'};

  static bool _running = false;
  static List<PredictionCardData>? _pending;

  static Future<bool> isEnabled() async =>
      (await safePrefs())?.getBool(_enabledKey) ?? false;

  /// Turning on asks Google for calendar write access; throws a
  /// [FormatException] with a user-facing message when that is not granted.
  /// Turning off removes the events this feature created.
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await safePrefs();
    if (enabled) {
      await _authorize(interactive: true);
      await prefs?.setBool(_enabledKey, true);
    } else {
      await prefs?.setBool(_enabledKey, false);
      await _removeAll();
    }
  }

  /// Reconciles the calendar with [cards]. Calls made while a sync is running
  /// collapse into one follow-up run with the latest cards.
  static Future<void> sync(List<PredictionCardData> cards) async {
    if (_running) {
      _pending = cards;
      return;
    }
    _running = true;
    try {
      var next = cards;
      while (true) {
        _pending = null;
        await _sync(next);
        final queued = _pending;
        if (queued == null) break;
        next = queued;
      }
    } catch (error) {
      AppLog.warn('Could not sync predictions to calendar: $error');
    } finally {
      _running = false;
    }
  }

  static Future<void> _sync(List<PredictionCardData> cards) async {
    if (!await isEnabled()) return;
    final api = await _authorize(interactive: false);
    if (api == null) return;

    final synced = await _loadSynced();
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final seen = <String>{};

    for (final card in cards) {
      final date = card.date;
      if (date == null || _skipKeys.contains(card.key)) continue;
      seen.add(card.key);
      final eventDay = DateTime(date.year, date.month, date.day);
      if (eventDay.isBefore(day)) continue;

      final signature = '${_dayString(eventDay)}|${card.label}|${card.detail}';
      final existing = synced[card.key];
      if (existing?.signature == signature) continue;
      if (existing != null) await _delete(api, existing.id);
      synced.remove(card.key);
      await _saveSynced(synced);
      final id = await _create(api, card, eventDay);
      synced[card.key] = (signature: signature, id: id);
      await _saveSynced(synced);
    }

    for (final key in synced.keys.toList()) {
      if (seen.contains(key)) continue;
      await _delete(api, synced[key]!.id);
      synced.remove(key);
      await _saveSynced(synced);
    }
  }

  static Future<void> _removeAll() async {
    final synced = await _loadSynced();
    if (synced.isEmpty) return;
    final api = await _authorize(interactive: false);
    if (api == null) return;
    for (final entry in synced.values) {
      await _delete(api, entry.id);
    }
    await _saveSynced({});
  }

  static Future<String> _create(
    gcal.CalendarApi api,
    PredictionCardData card,
    DateTime day,
  ) async {
    final created = await api.events.insert(
      gcal.Event(
        summary: card.label,
        description:
            '${card.detail}\n\nAdded by Personal from your predictions.',
        start: gcal.EventDateTime(date: day),
        end: gcal.EventDateTime(date: day.add(const Duration(days: 1))),
        transparency: 'transparent',
      ),
      'primary',
    );
    return created.id!;
  }

  static Future<void> _delete(gcal.CalendarApi api, String eventId) async {
    try {
      await api.events.delete('primary', eventId);
    } on gcal.DetailedApiRequestError catch (e) {
      // Already gone (404) or deleted earlier (410) is the state we want.
      if (e.status != 404 && e.status != 410) rethrow;
    }
  }

  static String _dayString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Future<gcal.CalendarApi?> _authorize({
    required bool interactive,
  }) async {
    final accounts = GoogleAccountService();
    final account = await accounts.resolveSessionAccount(
      interactive: interactive,
    );
    if (account == null) {
      if (!interactive) return null;
      throw const FormatException(
        'Google account not connected. Sign in from the calendar settings.',
      );
    }
    var authorization = await account.authorizationClient
        .authorizationForScopes(googleCalendarWriteScopes);
    if (authorization == null && interactive) {
      authorization = await account.authorizationClient.authorizeScopes(
        googleCalendarWriteScopes,
      );
    }
    if (authorization == null) {
      if (!interactive) return null;
      throw const FormatException(
        'Calendar access was not granted. Allow creating events to continue.',
      );
    }
    return gcal.CalendarApi(
      authorization.authClient(scopes: googleCalendarWriteScopes),
    );
  }

  static Future<Map<String, _Synced>> _loadSynced() async {
    final raw = (await safePrefs())?.getString(_syncedKey);
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map).entries)
          e.key as String: (
            signature: (e.value as Map)['sig'] as String,
            id: (e.value as Map)['id'] as String,
          ),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveSynced(Map<String, _Synced> synced) async {
    await (await safePrefs())?.setString(
      _syncedKey,
      jsonEncode({
        for (final e in synced.entries)
          e.key: {'sig': e.value.signature, 'id': e.value.id},
      }),
    );
  }
}

/// What was last written to the calendar for one prediction.
typedef _Synced = ({String signature, String id});
