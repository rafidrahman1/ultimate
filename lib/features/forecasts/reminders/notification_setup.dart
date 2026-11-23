import 'package:flutter/foundation.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/notifications/notification_log.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// What can stop a scheduled reminder from arriving on time. Every field is
/// true when that obstacle is cleared (or does not apply on this platform).
typedef ReminderHealth = ({
  bool notificationsAllowed,
  bool exactAlarms,
  bool batteryUnrestricted,
});

extension ReminderHealthX on ReminderHealth {
  bool get allGood =>
      notificationsAllowed && exactAlarms && batteryUnrestricted;
}

/// One-time local-notification and timezone setup shared by every reminder.
abstract final class NotificationSetup {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _testNotificationId = 9700;
  static const int _legacyMonthEndBaseId = 9800;
  static const int _legacyMonthEndCount = 12;
  static const int _legacyWeekEndBaseId = 9900;
  static const int _legacyWeekEndCount = 8;
  static const String _legacyCancelledKey = 'legacy_reminders_cancelled';
  static const String _batteryAskedKey = 'reminder_battery_exemption_asked_v1';
  static Future<void>? _initializing;

  static AndroidScheduleMode _scheduleMode =
      AndroidScheduleMode.exactAllowWhileIdle;

  /// How every reminder is scheduled: exact (fires on the minute, even in
  /// Doze) whenever Android allows it, otherwise inexact so it still arrives.
  static AndroidScheduleMode get scheduleMode => _scheduleMode;

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static Future<void> _refreshScheduleMode() async {
    final exact = await _android?.canScheduleExactNotifications() ?? true;
    _scheduleMode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Checks everything that could hold a reminder back.
  static Future<ReminderHealth> health() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return (
        notificationsAllowed: true,
        exactAlarms: true,
        batteryUnrestricted: true,
      );
    }
    await initialize();
    await _refreshScheduleMode();
    return (
      notificationsAllowed: await _android?.areNotificationsEnabled() ?? true,
      exactAlarms: _scheduleMode == AndroidScheduleMode.exactAllowWhileIdle,
      batteryUnrestricted:
          await Permission.ignoreBatteryOptimizations.isGranted,
    );
  }

  /// Asks for notification permission, or opens the app's system settings
  /// when Android will no longer show the prompt.
  static Future<void> fixNotifications() async {
    final granted = await _android?.requestNotificationsPermission() ?? true;
    if (!granted) await openAppSettings();
  }

  /// Opens the "Alarms & reminders" system page for this app.
  static Future<void> fixExactAlarms() async {
    await _android?.requestExactAlarmsPermission();
    await _refreshScheduleMode();
  }

  /// Asks Android to stop battery optimisation from delaying or dropping
  /// reminders for this app.
  static Future<void> fixBattery() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (status.isPermanentlyDenied) await openAppSettings();
  }

  /// Safe to call concurrently: every caller shares one initialisation.
  static Future<void> initialize() => _initializing ??= _initialize();

  static Future<void> _initialize() async {
    await _configureTimezone();

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: initSettings);

    await _requestPermissions();
    await _refreshScheduleMode();
  }

  /// Month-end analysis and weekly checklist reminders were removed; cancel
  /// any still scheduled by an older build.
  static Future<void> cancelLegacyReminders() async {
    final prefs = await safePrefs();
    if (prefs?.getBool(_legacyCancelledKey) ?? false) return;
    await initialize();
    for (var i = 0; i < _legacyMonthEndCount; i++) {
      await _plugin.cancel(id: _legacyMonthEndBaseId + i);
    }
    for (var i = 0; i < _legacyWeekEndCount; i++) {
      await _plugin.cancel(id: _legacyWeekEndBaseId + i);
    }
    await prefs?.setBool(_legacyCancelledKey, true);
  }

  /// Immediate notification to check that alerts get through.
  static Future<void> showTest({
    required String title,
    required String body,
  }) async {
    try {
      await initialize();
      await _plugin.show(
        id: _testNotificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_notification',
            'Test notification',
            channelDescription: 'Checks that notifications are working',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
      await NotificationLog.sync(
        owned: const [],
        scheduled: [
          LoggedNotification(
            id: _testNotificationId,
            title: title,
            body: body,
            at: DateTime.now(),
            channel: 'test_notification',
          ),
        ],
      );
    } catch (error) {
      AppLog.warn('Could not show test notification: $error');
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

    // Battery optimisation is the usual reason a scheduled reminder never
    // shows, so ask once up front; later fixes go through Settings.
    if (android != null) {
      final prefs = await safePrefs();
      if (!(prefs?.getBool(_batteryAskedKey) ?? false)) {
        await prefs?.setBool(_batteryAskedKey, true);
        if (!await Permission.ignoreBatteryOptimizations.isGranted) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      }
    }

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
}
