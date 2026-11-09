import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/forecasts/reminders/notification_setup.dart';
import 'package:personal/features/results/ai/cross_advice_ai.dart';
import 'package:timezone/timezone.dart' as tz;

const _adviceKey = 'cross_advice_v1';
const _enabledKey = 'cross_advice_reminders_v1';

const _baseId = 9200;
const _maxItems = 3;
const _daysAhead = 14;

/// Saved AI advice and the reminders scheduled from it. Reminders are
/// dated notifications for the next two weeks, replaced whenever the advice
/// is refreshed or the switch changes.
abstract final class AdviceReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<List<AdviceItem>> loadAdvice() async {
    final raw = (await safePrefs())?.getString(_adviceKey);
    if (raw == null) return const [];
    try {
      return [
        for (final e in (jsonDecode(raw) as List).whereType<Map>())
          AdviceItem.fromJson(e.cast<String, dynamic>()),
      ];
    } catch (error) {
      AppLog.warn('Could not read saved advice: $error');
      return const [];
    }
  }

  static Future<bool> isEnabled() async =>
      (await safePrefs())?.getBool(_enabledKey) ?? false;

  /// Saves [advice] and, when reminders are on, reschedules from it.
  static Future<void> saveAdvice(List<AdviceItem> advice) async {
    await (await safePrefs())?.setString(
      _adviceKey,
      jsonEncode([for (final a in advice) a.toJson()]),
    );
    await apply();
  }

  static Future<void> setEnabled(bool enabled) async {
    await (await safePrefs())?.setBool(_enabledKey, enabled);
    await apply();
  }

  /// Number of reminders the saved advice would send, for the UI.
  static int reminderCount(List<AdviceItem> advice) =>
      advice.where((a) => a.minutes != null).length;

  static Future<void> apply() async {
    try {
      await NotificationSetup.initialize();
      for (var i = 0; i < _maxItems * _daysAhead; i++) {
        await _plugin.cancel(id: _baseId + i);
      }
      if (!await isEnabled()) return;

      final advice = await loadAdvice();
      final now = tz.TZDateTime.now(tz.local);
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'advice_reminders',
          'Advice reminders',
          channelDescription: 'Reminders from your AI suggestions',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );
      for (var i = 0; i < advice.length && i < _maxItems; i++) {
        final item = advice[i];
        final minutes = item.minutes;
        if (minutes == null) continue;
        for (var d = 0; d < _daysAhead; d++) {
          final day = now.add(Duration(days: d));
          if (!item.weekdays.contains(day.weekday)) continue;
          final at = tz.TZDateTime(
            tz.local,
            day.year,
            day.month,
            day.day,
            minutes ~/ 60,
            minutes % 60,
          );
          if (!at.isAfter(now)) continue;
          await _plugin.zonedSchedule(
            id: _baseId + i * _daysAhead + d,
            title: 'Reminder',
            body: item.text,
            scheduledDate: at,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    } catch (error) {
      AppLog.warn('Could not schedule advice reminders: $error');
    }
  }
}
