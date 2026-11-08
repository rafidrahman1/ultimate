import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/dashboard/predictions/prediction_cards.dart';
import 'package:personal/features/forecasts/reminders/notification_setup.dart';
import 'package:personal/features/forecasts/reminders/prediction_calendar_service.dart';
import 'package:timezone/timezone.dart' as tz;

const _predictionsKey = 'prediction_reminders_enabled_v1';
const _odometerKey = 'odometer_reminder_enabled_v1';
const _appliedKey = 'reminder_schedule_signatures_v1';
const _predictionLeadKey = 'prediction_reminder_lead_days_v1';

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

/// How many days ahead of a predicted date the user wants to be reminded.
class ReminderTimes {
  const ReminderTimes({this.leadDays = 1});

  /// 0 = the day itself.
  final int leadDays;
}

// Fixed delivery times (minutes after midnight). Alarms are inexact, so
// Android may shift them a little; morning/evening slots tolerate that well.
const _predictionMinutes = 9 * 60;
const _digestWeekday = DateTime.sunday;
const _digestMinutes = 18 * 60;
const _odometerMinutes = 10 * 60;

/// Reminders for the dashboard predictions and the monthly odometer log.
///
/// Dated predictions get a reminder the day before (the evening before for
/// the commute); predictions with no date go into a weekly Sunday digest. The
/// text is a snapshot, so everything is rescheduled whenever the dashboard's
/// predictions change.
class PredictionNotificationService {
  PredictionNotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static List<PredictionCardData> _cards = const [];

  /// False until the dashboard has supplied its predictions in this process.
  /// Before that, rescheduling would cancel every reminder and schedule none.
  static bool _synced = false;
  static bool? _odometerLogged;
  static Map<DateTime, int> _leavePlan = const {};
  static ReminderTimes _times = const ReminderTimes();

  /// All reminders use inexact alarms: Android may batch them, which costs
  /// less battery than waking the device at an exact moment.
  static const AndroidScheduleMode _inexactMode =
      AndroidScheduleMode.inexactAllowWhileIdle;

  /// Everything the current state wants scheduled, collected by the `_plan*`
  /// methods and then reconciled against what is already scheduled.
  static final List<_Planned> _queued = [];

  static Future<bool> _flag(String key) async =>
      (await safePrefs())?.getBool(key) ?? true;

  static Future<void> _setFlag(String key, bool value) async {
    await (await safePrefs())?.setBool(key, value);
    await _apply();
  }

  static Future<bool> isPredictionRemindersEnabled() => _flag(_predictionsKey);
  static Future<bool> isOdometerReminderEnabled() => _flag(_odometerKey);

  static Future<void> setPredictionRemindersEnabled(bool enabled) =>
      _setFlag(_predictionsKey, enabled);
  static Future<void> setOdometerReminderEnabled(bool enabled) =>
      _setFlag(_odometerKey, enabled);

  static Future<ReminderTimes> loadTimes() async {
    final prefs = await safePrefs();
    return ReminderTimes(
      leadDays:
          prefs?.getInt(_predictionLeadKey) ?? const ReminderTimes().leadDays,
    );
  }

  /// Saves the chosen lead time and reschedules.
  static Future<void> saveTimes({int? leadDays}) async {
    final prefs = await safePrefs();
    if (leadDays != null) await prefs?.setInt(_predictionLeadKey, leadDays);
    await _apply();
  }

  /// Records what the dashboard shows now and reschedules from it.
  /// [odometerLogged] is null when the odometer prediction is switched off.
  static Future<void> sync(
    List<PredictionCardData> cards, {
    required bool? odometerLogged,
    Map<DateTime, int> leavePlan = const {},
  }) {
    _synced = true;
    _cards = cards;
    _leavePlan = leavePlan;
    _odometerLogged = odometerLogged;
    return _apply();
  }

  /// Re-plans from the last known predictions, e.g. after the calendar
  /// setting changes.
  static Future<void> reschedule() => _apply();

  static Future<void> _apply() async {
    if (!_synced) return;
    try {
      await NotificationSetup.initialize();
      _times = await loadTimes();
      _queued.clear();
      if (await isPredictionRemindersEnabled()) {
        _planPredictions(
          onCalendar: await PredictionCalendarService.isEnabled(),
        );
      }
      if (await isOdometerReminderEnabled()) _planOdometer();
      await _reconcile();
    } catch (error) {
      AppLog.warn('Could not schedule prediction reminders: $error');
    }
  }

  /// Each kind of reminder gets its own Android channel, so it can be muted
  /// or tuned on its own from the system notification settings.
  static NotificationDetails _forCard(String key) {
    switch (key) {
      case 'fuel':
      case 'bills':
      case 'budget':
      case 'payday':
        return _details('predictions_money', 'Money predictions');
      case 'oil':
      case 'bike':
        return _details('predictions_bike', 'Bike maintenance');
      case 'commute':
        return _details('predictions_commute', 'Commute');
      default:
        return _details('predictions_life', 'Life predictions');
    }
  }

  static final _commuteDetails = _details('predictions_commute', 'Commute');
  static final _digestDetails = _details(
    'predictions_digest',
    'Weekly predictions digest',
  );

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

  /// When to remind about a prediction landing on [date], or null when no
  /// useful moment is left.
  static tz.TZDateTime? _reminderAt(String key, DateTime date) {
    final now = tz.TZDateTime.now(tz.local);
    final evening = key == 'commute';
    final before = DateTime(date.year, date.month, date.day - 1);
    final lead = DateTime(date.year, date.month, date.day - _times.leadDays);
    const m = _predictionMinutes;
    final first = evening ? _at(before, 20) : _at(lead, m ~/ 60, m % 60);
    if (first.isAfter(now)) return first;
    final onDay = evening ? _at(date, 6) : _at(date, m ~/ 60, m % 60);
    return onDay.isAfter(now) ? onDay : null;
  }

  /// With [onCalendar], dated predictions already live on the user's calendar
  /// (which reminds them itself), so only the commute, undated digest and
  /// odometer reminders are sent from here.
  static void _planPredictions({required bool onCalendar}) {
    final now = tz.TZDateTime.now(tz.local);
    final horizon = now.add(const Duration(days: 180));
    var slot = 0;
    final undated = <PredictionCardData>[];
    for (final card in _cards) {
      if (card.key == 'odometer') continue;
      final date = card.date;
      if (date == null) {
        undated.add(card);
        continue;
      }
      if (card.key == 'commute') _scheduleLeaveNow(card, date);
      if (onCalendar && card.key != 'commute') continue;
      final at = _reminderAt(card.key, date);
      if (at == null || at.isAfter(horizon) || slot >= _predictionSlots) {
        continue;
      }
      _queue(
        id: _predictionBaseId + slot++,
        title: card.label,
        body: '${card.headline} · ${card.detail}',
        scheduledDate: at,
        notificationDetails: _forCard(card.key),
        androidScheduleMode: _inexactMode,
      );
    }

    _applyLeavePlan();

    if (undated.isEmpty) return;
    const dm = _digestMinutes;
    var sunday = _at(DateTime.now(), dm ~/ 60, dm % 60);
    while (sunday.weekday != _digestWeekday || !sunday.isAfter(now)) {
      sunday = _at(sunday.add(const Duration(days: 1)), dm ~/ 60, dm % 60);
    }
    _queue(
      id: _digestId,
      title: 'Your predictions this week',
      body: [
        for (final c in undated.take(4)) '${c.label}: ${c.headline}',
      ].join('\n'),
      scheduledDate: sunday,
      notificationDetails: _digestDetails,
      androidScheduleMode: _inexactMode,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
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
      final evening = _at(day.subtract(const Duration(days: 1)), 20);
      final nowAt = leave.subtract(const Duration(minutes: 10));
      if (evening.isAfter(now)) {
        _queue(
          id: _planEveningBaseId + slot,
          title: 'Leave for work',
          body: 'Tomorrow leave at $time to arrive on time.',
          scheduledDate: evening,
          notificationDetails: _commuteDetails,
          androidScheduleMode: _inexactMode,
        );
      }
      if (nowAt.isAfter(now)) {
        _queue(
          id: _planLeaveNowBaseId + slot,
          title: 'Leave for work in 10 minutes',
          body: 'Leave at $time to arrive on time.',
          scheduledDate: nowAt,
          notificationDetails: _commuteDetails,
          androidScheduleMode: _inexactMode,
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
      androidScheduleMode: _inexactMode,
    );
  }

  static void _planOdometer() {
    final logged = _odometerLogged;
    if (logged == null) return;

    final now = tz.TZDateTime.now(tz.local);
    const body = 'Log your bike odometer so service and oil timing stay exact.';
    final details = _details('odometer', 'Odometer log');

    const om = _odometerMinutes;

    // The 1st of each coming month, at the chosen time.
    for (var m = 1; m <= _odometerMonths; m++) {
      _queue(
        id: _odometerBaseId + m - 1,
        title: 'Log your odometer',
        body: body,
        scheduledDate: _at(
          DateTime(now.year, now.month + m, 1),
          om ~/ 60,
          om % 60,
        ),
        notificationDetails: details,
        androidScheduleMode: _inexactMode,
      );
    }

    // This month still unlogged: an evening nudge until it is.
    if (!logged) {
      var at = _at(DateTime.now(), 20);
      if (!at.isAfter(now)) at = _at(at.add(const Duration(days: 1)), 20);
      _queue(
        id: _odometerNudgeId,
        title: 'Odometer not logged this month',
        body: body,
        scheduledDate: at,
        notificationDetails: details,
        androidScheduleMode: _inexactMode,
      );
    }
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
