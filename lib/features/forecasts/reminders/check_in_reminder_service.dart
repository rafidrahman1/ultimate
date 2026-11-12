import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/forecasts/reminders/notification_setup.dart';
import 'package:timezone/timezone.dart' as tz;

const _enabledKey = 'check_in_reminder_enabled_v1';

const _baseId = 9300;
const _daysAhead = 14;
const _hour = 21;

/// An evening nudge to log how the day felt. Dated notifications for the next
/// two weeks, replaced whenever the app loads the journal or a check-in is
/// saved, so a day already logged is not nagged about.
abstract final class CheckInReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<bool> isEnabled() async =>
      (await safePrefs())?.getBool(_enabledKey) ?? true;

  static Future<void> setEnabled(bool enabled) async {
    await (await safePrefs())?.setBool(_enabledKey, enabled);
    await apply(loggedToday: _loggedToday);
  }

  static bool _loggedToday = false;

  /// Reschedules the reminders. [loggedToday] skips this evening's.
  static Future<void> apply({required bool loggedToday}) async {
    _loggedToday = loggedToday;
    try {
      await NotificationSetup.initialize();
      if (!await isEnabled()) {
        for (var d = 0; d < _daysAhead; d++) {
          await _plugin.cancel(id: _baseId + d);
        }
        return;
      }
      final now = tz.TZDateTime.now(tz.local);
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'check_in',
          'Daily check-in',
          channelDescription: 'Evening reminder to log how the day felt',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );
      for (var d = 0; d < _daysAhead; d++) {
        await _plugin.cancel(id: _baseId + d);
        final day = now.add(Duration(days: d));
        final at = tz.TZDateTime(tz.local, day.year, day.month, day.day, _hour);
        if (!at.isAfter(now) || (d == 0 && loggedToday)) continue;
        await _plugin.zonedSchedule(
          id: _baseId + d,
          title: 'How was today?',
          body: 'Log mood, energy and stress. It takes five seconds.',
          scheduledDate: at,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (error) {
      AppLog.warn('Could not schedule the check-in reminder: $error');
    }
  }
}
