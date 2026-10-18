import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:motohealth/core/app_log.dart';
import 'package:motohealth/features/garage/moto_logic.dart';
import 'package:motohealth/features/garage/moto_models.dart';
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
  static const _papersLeadDays = [30, 7, 0];
  static const _serviceLeadDays = [7, 0];

  static Future<void> initialize() async {
    if (_ready || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      tz_data.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
      Future<void> schedule(DateTime day, String title, String body) async {
        final at = tz.TZDateTime(tz.local, day.year, day.month, day.day, _hour);
        if (!at.isAfter(tz.TZDateTime.now(tz.local))) return;
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: at,
          title: title,
          body: body,
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

      for (final bike in data.bikes) {
        for (final p in data.papers.where((p) => p.bikeId == bike.id)) {
          for (final lead in _papersLeadDays) {
            await schedule(
              dayOf(p.expiry).subtract(Duration(days: lead)),
              '${bike.name}: ${p.type.label}',
              lead == 0
                  ? 'Expires today.'
                  : 'Expires in $lead days. Time to renew.',
            );
          }
        }
        final rate = dailyRate(data, bike, today);
        for (final s in taskStatuses(data, bike, today)) {
          final due = expectedDueDate(s, rate, today);
          if (due == null) continue;
          for (final lead in _serviceLeadDays) {
            await schedule(
              due.subtract(Duration(days: lead)),
              '${bike.name}: ${s.task.name}',
              lead == 0 ? 'Due about now.' : 'Due in about $lead days.',
            );
          }
        }
      }
    } catch (error) {
      AppLog.warn('Could not schedule reminders: $error');
    }
  }
}
