import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/dashboard/predictions/prediction_cards.dart';
import 'package:personal/features/forecasts/reminders/notification_setup.dart';
import 'package:personal/features/notifications/notification_log.dart';
import 'package:timezone/timezone.dart' as tz;

// Kept from when this switch covered every prediction, so a user who turned
// those off also keeps the commute reminder off.
const _commuteKey = 'prediction_reminders_enabled_v1';
const _appliedKey = 'reminder_schedule_signatures_v1';

// Dated-prediction, weekly-digest and odometer ids are no longer scheduled;
// kept so reminders left by older builds get cancelled.
const _predictionBaseId = 9000;
const _predictionSlots = 60;
const _digestId = 9060;
const _leaveNowId = 9061;
const _planLeaveNowBaseId = 9070;
// No longer scheduled; kept so reminders left by older builds get cancelled.
const _planEveningBaseId = 9084;
const _planDays = 14;
const _odometerBaseId = 9100;
const _odometerMonths = 12;
const _odometerNudgeId = 9150;

/// The "leave for work in 10 minutes" reminder.
///
/// Other predictions are not notified from here: dated ones go on the user's
/// Google Calendar (`PredictionCalendarService`), which reminds them itself.
/// The text is a snapshot, so everything is rescheduled whenever the
/// dashboard's predictions change.
class PredictionNotificationService {
  PredictionNotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static List<PredictionCardData> _cards = const [];

  /// False until the dashboard has supplied its predictions in this process.
  /// Before that, rescheduling would cancel every reminder and schedule none.
  static bool _synced = false;
  static Map<DateTime, int> _leavePlan = const {};

  /// Everything the current state wants scheduled, collected by the `_plan*`
  /// methods and then reconciled against what is already scheduled.
  static final List<_Planned> _queued = [];

  static Future<bool> _flag(String key) async =>
      (await safePrefs())?.getBool(key) ?? true;

  static Future<void> _setFlag(String key, bool value) async {
    await (await safePrefs())?.setBool(key, value);
    await _apply();
  }

  static Future<bool> isCommuteReminderEnabled() => _flag(_commuteKey);

  static Future<void> setCommuteReminderEnabled(bool enabled) =>
      _setFlag(_commuteKey, enabled);

  /// Records what the dashboard shows now and reschedules from it.
  static Future<void> sync(
    List<PredictionCardData> cards, {
    Map<DateTime, int> leavePlan = const {},
  }) {
    _synced = true;
    _cards = cards;
    _leavePlan = leavePlan;
    return _apply();
  }

  /// Re-plans from the last known predictions, e.g. once exact alarms are
  /// allowed.
  static Future<void> reschedule() => _apply();

  static Future<void> _apply() async {
    if (!_synced) return;
    try {
      await NotificationSetup.initialize();
      _queued.clear();
      if (await isCommuteReminderEnabled()) _planCommute();
      await _reconcile();
    } catch (error) {
      AppLog.warn('Could not schedule prediction reminders: $error');
    }
  }

  static final _commuteDetails = _details('predictions_commute', 'Commute');

  static NotificationDetails _details(String channel, String name) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          name,
          channelDescription: 'Reminders about $name',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      );

  static tz.TZDateTime _at(DateTime day, int hour, [int minute = 0]) =>
      tz.TZDateTime(tz.local, day.year, day.month, day.day, hour, minute);

  static void _planCommute() {
    for (final card in _cards) {
      final date = card.date;
      if (card.key == 'commute' && date != null) _scheduleLeaveNow(card, date);
    }
    _applyLeavePlan();
  }

  /// Reminders for the working days after the next one, from each weekday's
  /// own trip history, so they still arrive if the app is not opened.
  static void _applyLeavePlan() {
    final nextDate = [
      for (final c in _cards)
        if (c.key == 'commute' && c.date != null) c.date!,
    ].firstOrNull;
    final now = tz.TZDateTime.now(tz.local);
    var slot = 0;
    final days = _leavePlan.keys.toList()..sort();
    for (final day in days) {
      if (slot >= _planDays) break;
      if (nextDate != null &&
          day.year == nextDate.year &&
          day.month == nextDate.month &&
          day.day == nextDate.day) {
        continue;
      }
      final minutes = _leavePlan[day]!;
      final time =
          '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
          '${(minutes % 60).toString().padLeft(2, '0')}';
      final leave = _at(day, minutes ~/ 60, minutes % 60);
      final nowAt = leave.subtract(const Duration(minutes: 10));
      if (nowAt.isAfter(now)) {
        _queue(
          id: _planLeaveNowBaseId + slot,
          title: 'Leave for work in 10 minutes',
          body: 'Leave at $time to arrive on time.',
          scheduledDate: nowAt,
          notificationDetails: _commuteDetails,
          androidScheduleMode: NotificationSetup.scheduleMode,
        );
      }
      slot++;
    }
  }

  /// "Leave in 10 minutes", sent shortly before the predicted departure.
  static void _scheduleLeaveNow(PredictionCardData card, DateTime date) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(card.headline);
    if (match == null) return;
    final leave = _at(
      date,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
    final at = leave.subtract(const Duration(minutes: 10));
    if (!at.isAfter(tz.TZDateTime.now(tz.local))) return;
    _queue(
      id: _leaveNowId,
      title: 'Leave for work in 10 minutes',
      body: 'Leave at ${card.headline} to arrive on time. ${card.detail}',
      scheduledDate: at,
      notificationDetails: _commuteDetails,
      androidScheduleMode: NotificationSetup.scheduleMode,
    );
  }

  static void _queue({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
  }) {
    _queued.add(
      _Planned(
        id: id,
        title: title,
        body: body,
        at: scheduledDate,
        details: notificationDetails,
        mode: androidScheduleMode,
        match: matchDateTimeComponents,
      ),
    );
  }

  /// Every id this service may schedule.
  static Iterable<int> get _ownedIds sync* {
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

  /// Brings the scheduled notifications in line with [_queued], touching only
  /// those that changed. Each platform call wakes the alarm service, so an
  /// unchanged schedule costs nothing. The last-applied signature of each id
  /// is kept in preferences; with none recorded (first run, or an older
  /// build that scheduled without them) every owned id is reset.
  static Future<void> _reconcile() async {
    final prefs = await safePrefs();
    final stored = prefs?.getString(_appliedKey);
    var applied = <String, String>{};
    if (stored != null) {
      try {
        applied = (jsonDecode(stored) as Map).cast<String, String>();
      } catch (_) {
        applied = {};
      }
    }
    final known = stored != null;
    final wanted = {for (final n in _queued) n.id: n};
    final next = <String, String>{};

    for (final id in _ownedIds) {
      final plan = wanted[id];
      if (plan == null) {
        if (!known || applied.containsKey('$id')) {
          await _plugin.cancel(id: id);
        }
        continue;
      }
      final signature = plan.signature;
      next['$id'] = signature;
      if (known && applied['$id'] == signature) continue;
      await _plugin.zonedSchedule(
        id: id,
        title: plan.title,
        body: plan.body,
        scheduledDate: plan.at,
        notificationDetails: plan.details,
        androidScheduleMode: plan.mode,
        matchDateTimeComponents: plan.match,
      );
    }
    await prefs?.setString(_appliedKey, jsonEncode(next));
    await NotificationLog.sync(
      owned: _ownedIds,
      scheduled: [
        for (final n in _queued)
          LoggedNotification(
            id: n.id,
            title: n.title,
            body: n.body,
            at: n.at,
            channel: n.details.android?.channelId,
            repeat: n.match == null ? null : NotificationRepeat.weekly,
          ),
      ],
    );
  }
}

class _Planned {
  const _Planned({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.details,
    required this.mode,
    required this.match,
  });

  final int id;
  final String title;
  final String body;
  final tz.TZDateTime at;
  final NotificationDetails details;
  final AndroidScheduleMode mode;
  final DateTimeComponents? match;

  String get signature =>
      '$title|$body|${at.millisecondsSinceEpoch}|${details.android?.channelId}'
      '|${mode.name}|${match?.name}';
}
