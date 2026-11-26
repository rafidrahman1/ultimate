import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/forecasts/reminders/notification_setup.dart';
import 'package:personal/features/notifications/notification_log.dart';

/// Set once the leftovers below have been cancelled on this device.
const _clearedKey = 'prediction_reminders_cleared_v1';

// Keys and ids older builds used for prediction reminders, the last of which
// was "Leave for work in 10 minutes".
const _oldKeys = [
  'prediction_reminders_enabled_v1',
  'reminder_schedule_signatures_v1',
];
const _predictionBaseId = 9000;
const _predictionSlots = 60;
const _digestId = 9060;
const _leaveNowId = 9061;
const _planLeaveNowBaseId = 9070;
const _planEveningBaseId = 9084;
const _planDays = 14;
const _odometerBaseId = 9100;
const _odometerMonths = 12;
const _odometerNudgeId = 9150;

/// The app no longer sends prediction reminders from the phone (dated
/// predictions go on Google Calendar instead). This cancels any that older
/// builds left scheduled, once per install.
abstract final class PredictionNotificationService {
  static Future<void>? _running;

  static Future<void> cancelLeftovers() => _running ??= _cancelLeftovers();

  static Future<void> _cancelLeftovers() async {
    try {
      final prefs = await safePrefs();
      if (prefs == null || (prefs.getBool(_clearedKey) ?? false)) return;
      await NotificationSetup.initialize();
      final plugin = FlutterLocalNotificationsPlugin();
      final ids = _oldIds.toList();
      for (final id in ids) {
        await plugin.cancel(id: id);
      }
      await NotificationLog.sync(owned: ids, scheduled: const []);
      for (final key in _oldKeys) {
        await prefs.remove(key);
      }
      await prefs.setBool(_clearedKey, true);
    } catch (error) {
      AppLog.warn('Could not cancel old prediction reminders: $error');
    }
  }

  static Iterable<int> get _oldIds sync* {
    for (var i = 0; i < _predictionSlots; i++) {
      yield _predictionBaseId + i;
    }
    yield _digestId;
    yield _leaveNowId;
    for (var i = 0; i < _planDays; i++) {
      yield _planLeaveNowBaseId + i;
      yield _planEveningBaseId + i;
    }
    for (var i = 0; i < _odometerMonths; i++) {
      yield _odometerBaseId + i;
    }
    yield _odometerNudgeId;
  }
}
