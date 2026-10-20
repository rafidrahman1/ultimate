import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:motohealth/core/app_log.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/reminders/reminder_plan.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules local notifications for expiring papers and maintenance that
/// falls due. Everything is rebuilt from the data after each change, so there
/// is no state to drift out of sync.
class ReminderService {
  ReminderService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _hour = 9;

  static Future<void> initialize() async {
    if (_ready || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      tz_data.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_notify'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      _ready = true;
    } catch (error) {
      AppLog.warn('Could not set up reminders: $error');
    }
  }

  static Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (error) {
      AppLog.warn('Notification permission request failed: $error');
    }
  }

  /// Replaces every scheduled reminder with those the data calls for.
  static Future<void> sync(MotoData data, {DateTime? now}) async {
    if (!_ready) return;
    final today = dayOf(now ?? DateTime.now());
    try {
      await _plugin.cancelAll();
      var id = 1;
      for (final r in planReminders(data, today)) {
        final at = tz.TZDateTime(
          tz.local,
          r.day.year,
          r.day.month,
          r.day.day,
          _hour,
        );
        if (!at.isAfter(tz.TZDateTime.now(tz.local))) continue;
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: at,
          title: r.title,
          body: r.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'reminders',
              'Reminders',
              channelDescription: 'Document expiry and maintenance due dates',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (error) {
      AppLog.warn('Could not schedule reminders: $error');
    }
  }
}
