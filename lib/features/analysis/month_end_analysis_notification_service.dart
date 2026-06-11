import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:personal/core/app_log.dart';

const _monthEndReminderEnabledKey = 'month_end_analysis_reminder_enabled_v1';

class MonthEndAnalysisNotificationService {
  MonthEndAnalysisNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _baseNotificationId = 9800;
  static const int _monthsToSchedule = 12;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await _configureTimezone();

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: initSettings);

    await _requestPermissions();
    _initialized = true;
  }

  static Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_monthEndReminderEnabledKey) ?? true;
  }

  static Future<void> setReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monthEndReminderEnabledKey, enabled);
    await scheduleFromSettings();
  }

  static Future<void> scheduleFromSettings() async {
    await initialize();
    final enabled = await isReminderEnabled();
    if (enabled) {
      await _scheduleMonthEndReminders();
    } else {
      await _cancelMonthEndReminders();
    }
  }

  static Future<void> _configureTimezone() async {
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (error) {
      AppLog.warn('Timezone init failed, falling back to UTC: $error');
      tz.setLocalLocation(tz.UTC);
    }
  }

  static Future<void> _requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macos = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macos?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> _cancelMonthEndReminders() async {
    for (var i = 0; i < _monthsToSchedule; i++) {
      await _plugin.cancel(id: _baseNotificationId + i);
    }
  }

  static Future<void> _scheduleMonthEndReminders() async {
    await _cancelMonthEndReminders();
    final now = tz.TZDateTime.now(tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'month_end_analysis',
        'Month-end analysis reminders',
        channelDescription: 'Reminders to review and plan next month analysis',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    for (var offset = 0; offset < _monthsToSchedule; offset++) {
      final targetMonth = tz.TZDateTime(
        tz.local,
        now.year,
        now.month + offset,
        1,
      );
      final scheduledAt = _monthEndAt8Pm(targetMonth);
      if (scheduledAt.isBefore(now)) continue;

      final nextMonth = tz.TZDateTime(
        tz.local,
        targetMonth.year,
        targetMonth.month + 1,
        1,
      );

      await _plugin.zonedSchedule(
        id: _baseNotificationId + offset,
        title: 'Month-end analysis reminder',
        body:
            'Time to prepare analysis for ${_monthName(nextMonth.month)} ${nextMonth.year}.',
        scheduledDate: scheduledAt,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static tz.TZDateTime _monthEndAt8Pm(tz.TZDateTime monthStart) {
    final endOfMonth = tz.TZDateTime(
      tz.local,
      monthStart.year,
      monthStart.month + 1,
      0,
      20,
    );
    return endOfMonth;
  }

  static String _monthName(int month) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
