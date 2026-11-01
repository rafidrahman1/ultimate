import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:personal/core/app_log.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// One-time local-notification and timezone setup shared by every reminder.
abstract final class NotificationSetup {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _testNotificationId = 9700;
  static const int _legacyMonthEndBaseId = 9800;
  static const int _legacyMonthEndCount = 12;
  static const int _legacyWeekEndBaseId = 9900;
  static const int _legacyWeekEndCount = 8;
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

  /// Month-end analysis and weekly checklist reminders were removed; cancel
  /// any still scheduled by an older build.
  static Future<void> cancelLegacyReminders() async {
    await initialize();
    for (var i = 0; i < _legacyMonthEndCount; i++) {
      await _plugin.cancel(id: _legacyMonthEndBaseId + i);
    }
    for (var i = 0; i < _legacyWeekEndCount; i++) {
      await _plugin.cancel(id: _legacyWeekEndBaseId + i);
    }
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
