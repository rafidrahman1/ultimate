import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/forecasts/commute_alert/commute_ai.dart';
import 'package:personal/features/forecasts/commute_alert/commute_estimate.dart';
import 'package:personal/features/forecasts/commute_alert/commute_profile.dart';
import 'package:personal/features/forecasts/commute_alert/google_traffic_client.dart';
import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/notifications/notification_log.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _enabledKey = 'commute_alert_enabled_v1';
const _timeKey = 'commute_alert_minutes_v1';
const _modeKey = 'commute_alert_mode_v1';
const _useAiKey = 'commute_alert_use_ai_v1';
const _prepKey = 'commute_alert_prep_minutes_v1';
const _ringKey = 'commute_alert_ring_v1';
const _profileKey = 'commute_alert_profile_v1';
const _googleLogKey = 'commute_alert_google_minutes_v1';
const _lastKey = 'commute_alert_last_v1';
const _leaveKey = 'commute_alert_leave_v1';

/// Secure-storage entry for the Google Maps API key, for backup.
const commuteMapsKeyStorageKey = 'commute_alert_maps_key_v1';

const _checkAlarmId = 4201;
const _leaveAlarmId = 4202;
const _notificationId = 9200;
const _leaveNotificationId = 9201;
const _channel = 'predictions_commute';
const _alarmChannel = 'commute_leave_alarm';

/// Default traffic check time: 07:00.
const _defaultMinutes = 7 * 60;

/// Days of Google readings kept for learning how they compare with your
/// actual trips.
const _googleLogDays = 90;

/// How late a leave alarm may still ring, e.g. after the phone was off.
const _leaveAlarmGrace = Duration(minutes: 15);

/// The settings the reminder runs with.
typedef CommuteAlertSettings = ({
  bool enabled,
  int minutes,
  CommuteTravelMode mode,
  bool hasKey,
  bool useAi,
  int prepMinutes,
  bool ringAlarm,
});

/// The last estimate, for the settings screen.
typedef CommuteAlertResult = ({DateTime at, String title, String body});

/// "When to leave for work": at a time you pick on each working day, asks
/// Google Maps how long the trip takes with today's traffic, combines that
/// with your own trips from the timeline (and, if switched on, asks the AI
/// to weigh it all), notifies you when to leave, and rings an alarm then.
///
/// It runs from Android alarms in the background, so it works with the app
/// closed. The timeline is too big to load there, so whatever it needs from
/// it ([CommuteProfile]) is saved each time the app works out forecasts.
abstract final class CommuteAlertService {
  static const _secure = FlutterSecureStorage();

  static Future<CommuteAlertSettings> settings() async {
    final prefs = await safePrefs();
    return (
      enabled: prefs?.getBool(_enabledKey) ?? false,
      minutes: prefs?.getInt(_timeKey) ?? _defaultMinutes,
      mode: CommuteTravelMode.fromName(prefs?.getString(_modeKey)),
      hasKey: (await _mapsKey())?.isNotEmpty ?? false,
      useAi: prefs?.getBool(_useAiKey) ?? false,
      prepMinutes: prefs?.getInt(_prepKey) ?? defaultCommutePrepMinutes,
      ringAlarm: prefs?.getBool(_ringKey) ?? true,
    );
  }

  static Future<void> setEnabled(bool enabled) async {
    await (await safePrefs())?.setBool(_enabledKey, enabled);
    if (!enabled) await _cancelLeaveAlarm();
    await schedule();
  }

  static Future<void> setTime(int minutes) async {
    await (await safePrefs())?.setInt(_timeKey, minutes);
    await schedule();
  }

  static Future<void> setMode(CommuteTravelMode mode) async =>
      (await safePrefs())?.setString(_modeKey, mode.name);

  static Future<void> setUseAi(bool useAi) async =>
      (await safePrefs())?.setBool(_useAiKey, useAi);

  static Future<void> setPrepMinutes(int minutes) async =>
      (await safePrefs())?.setInt(_prepKey, minutes.clamp(0, 30));

  static Future<void> setRingAlarm(bool ring) async {
    await (await safePrefs())?.setBool(_ringKey, ring);
    if (!ring) await _cancelLeaveAlarm();
  }

  static Future<void> setMapsKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _secure.delete(key: commuteMapsKeyStorageKey);
    } else {
      await _secure.write(key: commuteMapsKeyStorageKey, value: trimmed);
    }
  }

  static Future<String?> _mapsKey() async {
    try {
      return await _secure.read(key: commuteMapsKeyStorageKey);
    } catch (error) {
      AppLog.warn('Could not read the Google Maps key: $error');
      return null;
    }
  }

  static Future<CommuteProfile?> profile() async {
    final raw = (await safePrefs())?.getString(_profileKey);
    if (raw == null) return null;
    try {
      return CommuteProfile.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (error) {
      AppLog.warn('Could not read the commute profile: $error');
      return null;
    }
  }

  static Future<CommuteAlertResult?> lastResult() async {
    final raw = (await safePrefs())?.getString(_lastKey);
    if (raw == null) return null;
    try {
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return (
        at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
        title: json['title'] as String,
        body: json['body'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// When the leave alarm will ring, or null when none is set.
  static Future<DateTime?> pendingLeaveAlarm() async {
    final leave = _readLeave(await safePrefs());
    if (leave == null || !leave.at.isAfter(clock.now())) return null;
    return leave.at;
  }

  static String? _savedProfileJson;

  /// Saves what the reminder needs from the timeline and reschedules it.
  /// Called whenever the app works out forecasts; cheap when nothing changed.
  static Future<void> refreshProfile(LifeInputs inputs) async {
    try {
      final prefs = await safePrefs();
      if (prefs == null) return;
      final built = buildCommuteProfile(
        inputs,
        googleMinutes: _googleLog(prefs.getString(_googleLogKey)),
      );
      final json = built == null ? null : jsonEncode(built.toJson());
      if (json == _savedProfileJson && json != null) return;
      _savedProfileJson = json;
      if (json == null) {
        await prefs.remove(_profileKey);
      } else {
        await prefs.setString(_profileKey, json);
      }
      await schedule();
    } catch (error) {
      AppLog.warn('Could not update the commute reminder: $error');
    }
  }

  /// The next working day at the check time, or null when off, when there
  /// is no profile yet, or when no working day is in sight.
  static Future<DateTime?> nextRun() async {
    final s = await settings();
    if (!s.enabled) return null;
    final p = await profile();
    if (p == null) return null;
    final now = clock.now();
    for (var d = 0; d < 21; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      final at = day.add(Duration(minutes: s.minutes));
      if (at.isAfter(now) && p.isCommuteDay(day)) return at;
    }
    return null;
  }

  /// Sets (or clears) the traffic check alarm for [nextRun].
  static Future<void> schedule() async {
    if (!Platform.isAndroid) return;
    try {
      await AndroidAlarmManager.cancel(_checkAlarmId);
      final next = await nextRun();
      await NotificationLog.sync(
        owned: const [_notificationId],
        scheduled: [
          if (next != null)
            LoggedNotification(
              id: _notificationId,
              title: 'When to leave for work',
              body:
                  'Checks Google traffic and your trips, then tells you '
                  'when to leave.',
              at: next,
              channel: _channel,
            ),
        ],
      );
      if (next == null) return;
      await _setAlarm(next, _checkAlarmId, commuteAlertFired);
    } catch (error) {
      AppLog.warn('Could not schedule the commute reminder: $error');
    }
  }

  static Future<void> _setAlarm(
    DateTime at,
    int id,
    Future<void> Function() callback,
  ) async {
    Future<bool> set({required bool exact}) => AndroidAlarmManager.oneShotAt(
      at,
      id,
      callback,
      exact: exact,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
    try {
      await set(exact: true);
    } catch (_) {
      // Exact alarms not allowed: still run, a little late if need be.
      await set(exact: false);
    }
  }

  /// Works out today's (or the next working day's) leave time, notifies,
  /// sets the leave alarm, and returns it. [fromAlarm] is the scheduled run;
  /// a manual check also works on days off, for the next working day.
  static Future<CommuteAlertResult?> run({bool fromAlarm = false}) async {
    final p = await profile();
    final s = await settings();
    if (p == null) {
      if (!fromAlarm) {
        throw const FormatException(
          'Not enough home-to-work trips in your timeline yet.',
        );
      }
      return null;
    }
    if (fromAlarm && !s.enabled) return null;

    final now = clock.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!p.isCommuteDay(day)) {
      if (fromAlarm) {
        await schedule();
        return null;
      }
      for (var d = 1; d < 15 && !p.isCommuteDay(day); d++) {
        day = DateTime(now.year, now.month, now.day + d);
      }
    }
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final prefs = await safePrefs();
    final googleLog = _googleLog(prefs?.getString(_googleLogKey));

    TrafficReading? traffic;
    final notes = <String>[];
    final key = await _mapsKey();
    if (key != null && key.isNotEmpty) {
      try {
        traffic = await _traffic(key, p, s, day, now);
      } catch (error) {
        notes.add(
          '(Traffic: ${error is FormatException ? error.message : error})',
        );
        AppLog.warn('Commute traffic check failed: $error');
      }
    }

    var estimate = estimateLeave(
      p,
      day,
      traffic: traffic,
      prepMinutes: s.prepMinutes,
    );
    if (s.useAi) {
      try {
        estimate = await _refineWithAi(p, s, day, now, estimate, googleLog);
      } catch (error) {
        notes.add('(AI not used: ${_short(error)})');
        AppLog.warn('Commute AI refinement failed: $error');
      }
    }

    final title = isToday
        ? estimate.titleAt(now)
        : '${estimate.titleAt(day)} on ${weekdayShort(day)}';
    final body = [estimate.body, ...notes].join(' ');

    await _notify(title, body);
    if (isToday && s.ringAlarm) {
      final leave = day.add(Duration(minutes: estimate.leaveAt));
      if (leave.isAfter(now.add(const Duration(minutes: 1)))) {
        await _setLeaveAlarm(prefs, leave, estimate);
      } else if (fromAlarm) {
        await _ring('Leave for work now', estimate.body);
      }
    }
    if (traffic != null && isToday) {
      // Door to door by Google, so the learned ratio compares like with like.
      await _recordGoogle(
        prefs,
        googleLog,
        day,
        traffic.withTraffic + s.prepMinutes,
      );
    }
    await prefs?.setString(
      _lastKey,
      jsonEncode({
        'at': now.millisecondsSinceEpoch,
        'title': title,
        'body': body,
      }),
    );
    if (fromAlarm) await schedule();
    return (at: now, title: title, body: body);
  }

  static Future<LeaveEstimate> _refineWithAi(
    CommuteProfile p,
    CommuteAlertSettings s,
    DateTime day,
    DateTime now,
    LeaveEstimate baseline,
    Map<DateTime, int> googleLog,
  ) async {
    // Read the AI settings without the widget tree (this may run from a
    // background alarm).
    final container = ProviderContainer();
    try {
      final ai = await container.read(aiSettingsProvider.future);
      if (!canRunCommuteAi(ai)) {
        throw const FormatException('no AI provider key, or API calls off');
      }
      return await refineLeaveWithAi(
        settings: ai,
        profile: p,
        day: day,
        now: now,
        baseline: baseline,
        travelMode: s.mode.label,
        googleLog: googleLog,
      );
    } finally {
      container.dispose();
    }
  }

  static String _short(Object error) {
    final text = error is FormatException ? error.message : '$error';
    return text.length > 80 ? '${text.substring(0, 80)}…' : text;
  }

  /// Google's ride time for setting off around your usual time, asked again
  /// for the new time when traffic moves it by more than 10 minutes.
  static Future<TrafficReading> _traffic(
    String key,
    CommuteProfile p,
    CommuteAlertSettings s,
    DateTime day,
    DateTime now,
  ) async {
    final client = GoogleTrafficClient();
    DateTime departAt(int leaveAt) {
      // You ride off a few minutes after walking out of the door.
      final at = day.add(Duration(minutes: leaveAt + s.prepMinutes));
      final soonest = now.add(const Duration(minutes: 1));
      return at.isBefore(soonest) ? soonest : at;
    }

    Future<TrafficReading> ask(int leaveAt) => client.tripMinutes(
      apiKey: key,
      from: p.home,
      to: p.work,
      departure: departAt(leaveAt),
      mode: s.mode,
    );

    final guess = historyLeaveAt(p, day);
    var reading = await ask(guess);
    final first = estimateLeave(
      p,
      day,
      traffic: reading,
      prepMinutes: s.prepMinutes,
    );
    if ((first.leaveAt - guess).abs() > 10) {
      reading = await ask(first.leaveAt);
    }
    return reading;
  }

  static Future<void> _recordGoogle(
    SharedPreferences? prefs,
    Map<DateTime, int> log,
    DateTime day,
    int minutes,
  ) async {
    if (prefs == null) return;
    log[day] = minutes;
    final cutoff = day.subtract(const Duration(days: _googleLogDays));
    log.removeWhere((d, _) => d.isBefore(cutoff));
    await prefs.setString(
      _googleLogKey,
      jsonEncode({
        for (final e in log.entries) e.key.toIso8601String(): e.value,
      }),
    );
  }

  static Map<DateTime, int> _googleLog(String? raw) {
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map).entries)
          DateTime.parse(e.key as String): e.value as int,
      };
    } catch (_) {
      return {};
    }
  }

  // ---- Leave alarm ----------------------------------------------------

  static ({DateTime at, String body})? _readLeave(SharedPreferences? prefs) {
    final raw = prefs?.getString(_leaveKey);
    if (raw == null) return null;
    try {
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return (
        at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
        body: json['body'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _setLeaveAlarm(
    SharedPreferences? prefs,
    DateTime at,
    LeaveEstimate estimate,
  ) async {
    if (!Platform.isAndroid) return;
    await prefs?.setString(
      _leaveKey,
      jsonEncode({'at': at.millisecondsSinceEpoch, 'body': estimate.body}),
    );
    await AndroidAlarmManager.cancel(_leaveAlarmId);
    await _setAlarm(at, _leaveAlarmId, commuteLeaveAlarmFired);
    await NotificationLog.sync(
      owned: const [_leaveNotificationId],
      scheduled: [
        LoggedNotification(
          id: _leaveNotificationId,
          title: 'Leave for work now',
          body: estimate.body,
          at: at,
          channel: _alarmChannel,
        ),
      ],
    );
  }

  static Future<void> _cancelLeaveAlarm() async {
    if (!Platform.isAndroid) return;
    try {
      await (await safePrefs())?.remove(_leaveKey);
      await AndroidAlarmManager.cancel(_leaveAlarmId);
      await NotificationLog.sync(
        owned: const [_leaveNotificationId],
        scheduled: const [],
      );
    } catch (error) {
      AppLog.warn('Could not cancel the leave alarm: $error');
    }
  }

  /// Rings the saved leave alarm, unless it was cancelled or is long past.
  static Future<void> ringSavedLeaveAlarm() async {
    final prefs = await safePrefs();
    final leave = _readLeave(prefs);
    if (leave == null) return;
    await prefs?.remove(_leaveKey);
    final s = await settings();
    if (!s.enabled || !s.ringAlarm) return;
    final late = clock.now().difference(leave.at);
    if (late > _leaveAlarmGrace || late < const Duration(minutes: -2)) return;
    await _ring('Leave for work now', leave.body);
  }

  static Future<FlutterLocalNotificationsPlugin> _plugin() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
    );
    return plugin;
  }

  /// A loud, repeating alarm-sound notification until dismissed or for
  /// five minutes, whichever is sooner.
  static Future<void> _ring(String title, String body) async {
    final plugin = await _plugin();
    await plugin.show(
      id: _leaveNotificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _alarmChannel,
          'Leave-for-work alarm',
          channelDescription: 'Rings when it is time to leave for work',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          sound: const UriAndroidNotificationSound(
            'content://settings/system/alarm_alert',
          ),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
          // FLAG_INSISTENT: repeat the sound until the alarm is dismissed.
          additionalFlags: Int32List.fromList([4]),
          timeoutAfter: 5 * 60 * 1000,
          autoCancel: true,
          styleInformation: BigTextStyleInformation(body),
          actions: const [
            AndroidNotificationAction('stop', 'Stop', cancelNotification: true),
          ],
        ),
      ),
    );
    await NotificationLog.sync(
      owned: const [_leaveNotificationId],
      scheduled: [
        LoggedNotification(
          id: _leaveNotificationId,
          title: title,
          body: body,
          at: clock.now(),
          channel: _alarmChannel,
        ),
      ],
    );
  }

  static Future<void> _notify(String title, String body) async {
    final plugin = await _plugin();
    await plugin.show(
      id: _notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel,
          'Commute',
          channelDescription: 'When to leave for work',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
    );
    await NotificationLog.sync(
      owned: const [],
      scheduled: [
        LoggedNotification(
          id: _notificationId,
          title: title,
          body: body,
          at: clock.now(),
          channel: _channel,
        ),
      ],
    );
  }
}

/// The traffic check alarm's entry point, run in a background isolate.
@pragma('vm:entry-point')
Future<void> commuteAlertFired() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await CommuteAlertService.run(fromAlarm: true);
  } catch (error) {
    AppLog.warn('Commute reminder failed: $error');
    await CommuteAlertService.schedule();
  }
}

/// The leave alarm's entry point, run in a background isolate.
@pragma('vm:entry-point')
Future<void> commuteLeaveAlarmFired() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await CommuteAlertService.ringSavedLeaveAlarm();
  } catch (error) {
    AppLog.warn('Leave-for-work alarm failed: $error');
  }
}
