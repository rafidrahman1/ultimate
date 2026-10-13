import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:personal/core/app_log.dart';
import 'package:personal/core/prefs.dart';
import 'package:personal/features/analysis/month_end_analysis_notification_service.dart';
import 'package:personal/features/dashboard/prediction_cards.dart';

const _predictionsKey = 'prediction_reminders_enabled_v1';
const _odometerKey = 'odometer_reminder_enabled_v1';
const _exactAskedKey = 'exact_alarm_asked_v1';
const _predictionTimeKey = 'prediction_reminder_minutes_v1';
const _predictionLeadKey = 'prediction_reminder_lead_days_v1';
const _digestWeekdayKey = 'prediction_digest_weekday_v1';
const _digestTimeKey = 'prediction_digest_minutes_v1';
const _odometerTimeKey = 'odometer_reminder_minutes_v1';

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

/// When the user wants each kind of reminder to arrive.
class ReminderTimes {
  const ReminderTimes({
    this.predictionMinutes = 9 * 60,
    this.leadDays = 1,
    this.digestWeekday = DateTime.sunday,
    this.digestMinutes = 18 * 60,
    this.odometerMinutes = 9 * 60,
  });

  /// Minutes after midnight for dated prediction reminders.
  final int predictionMinutes;

  /// How many days before the predicted date to remind (0 = the day itself).
  final int leadDays;

  /// [DateTime.monday]..[DateTime.sunday] for the undated-predictions digest.
  final int digestWeekday;
  final int digestMinutes;
  final int odometerMinutes;
}

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
  static bool? _odometerLogged;
  static Map<DateTime, int> _leavePlan = const {};
  static ReminderTimes _times = const ReminderTimes();
  static AndroidScheduleMode _mode = AndroidScheduleMode.inexactAllowWhileIdle;

  static Future<bool> _flag(String key) async =>
      (await safePrefs())?.getBool(key) ?? true;

  static Future<void> _setFlag(String key, bool value) async {
    await (await safePrefs())?.setBool(key, value);
    if (value) await _prepareExact(ask: true);
    await _apply();
  }

  /// Picks exact alarms when Android allows them, so Doze cannot hold a
  /// reminder back. [ask] sends the user to the system screen to allow them,
  /// once.
  static Future<void> _prepareExact({bool ask = false}) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    var allowed = await android.canScheduleExactNotifications() ?? false;
    final prefs = await safePrefs();
    if (!allowed && ask && !(prefs?.getBool(_exactAskedKey) ?? false)) {
      await prefs?.setBool(_exactAskedKey, true);
      allowed = await android.requestExactAlarmsPermission() ?? false;
    }
    _mode = allowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static Future<bool> isPredictionRemindersEnabled() => _flag(_predictionsKey);
  static Future<bool> isOdometerReminderEnabled() => _flag(_odometerKey);

  static Future<void> setPredictionRemindersEnabled(bool enabled) =>
      _setFlag(_predictionsKey, enabled);
  static Future<void> setOdometerReminderEnabled(bool enabled) =>
      _setFlag(_odometerKey, enabled);

  static Future<ReminderTimes> loadTimes() async {
    final prefs = await safePrefs();
    const d = ReminderTimes();
    return ReminderTimes(
      predictionMinutes:
          prefs?.getInt(_predictionTimeKey) ?? d.predictionMinutes,
      leadDays: prefs?.getInt(_predictionLeadKey) ?? d.leadDays,
      digestWeekday: prefs?.getInt(_digestWeekdayKey) ?? d.digestWeekday,
      digestMinutes: prefs?.getInt(_digestTimeKey) ?? d.digestMinutes,
      odometerMinutes: prefs?.getInt(_odometerTimeKey) ?? d.odometerMinutes,
    );
  }

  /// Saves the chosen times and reschedules. Null arguments keep the value.
  static Future<void> saveTimes({
    int? predictionMinutes,
    int? leadDays,
    int? digestWeekday,
    int? digestMinutes,
    int? odometerMinutes,
  }) async {
    final prefs = await safePrefs();
    Future<void> put(String key, int? value) async {
      if (value != null) await prefs?.setInt(key, value);
    }

    await put(_predictionTimeKey, predictionMinutes);
    await put(_predictionLeadKey, leadDays);
    await put(_digestWeekdayKey, digestWeekday);
    await put(_digestTimeKey, digestMinutes);
    await put(_odometerTimeKey, odometerMinutes);
    await _apply();
  }

  /// Records what the dashboard shows now and reschedules from it.
  /// [odometerLogged] is null when the odometer prediction is switched off.
  static Future<void> sync(
    List<PredictionCardData> cards, {
    required bool? odometerLogged,
    Map<DateTime, int> leavePlan = const {},
  }) {
    _cards = cards;
    _leavePlan = leavePlan;
    _odometerLogged = odometerLogged;
    return _apply();
  }

  static Future<void> _apply() async {
    try {
      await MonthEndAnalysisNotificationService.initialize();
      await _prepareExact(ask: true);
      _times = await loadTimes();
      await _applyPredictions(await isPredictionRemindersEnabled());
      await _applyOdometer(await isOdometerReminderEnabled());
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
    final m = _times.predictionMinutes;
    final first = evening ? _at(before, 20) : _at(lead, m ~/ 60, m % 60);
    if (first.isAfter(now)) return first;
    final onDay = evening ? _at(date, 6) : _at(date, m ~/ 60, m % 60);
    return onDay.isAfter(now) ? onDay : null;
  }

  static Future<void> _applyPredictions(bool enabled) async {
    for (var i = 0; i < _predictionSlots; i++) {
      await _plugin.cancel(id: _predictionBaseId + i);
    }
    await _plugin.cancel(id: _digestId);
    await _plugin.cancel(id: _leaveNowId);
    for (var i = 0; i < _planDays; i++) {
      await _plugin.cancel(id: _planLeaveNowBaseId + i);
      await _plugin.cancel(id: _planEveningBaseId + i);
    }
    if (!enabled) return;

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
      if (card.key == 'commute') await _scheduleLeaveNow(card, date);
      final at = _reminderAt(card.key, date);
      if (at == null || at.isAfter(horizon) || slot >= _predictionSlots) {
        continue;
      }
      await _plugin.zonedSchedule(
        id: _predictionBaseId + slot++,
        title: card.label,
        body: '${card.headline} · ${card.detail}',
        scheduledDate: at,
        notificationDetails: _forCard(card.key),
        androidScheduleMode: _mode,
      );
    }

    await _applyLeavePlan();

    if (undated.isEmpty) return;
    final dm = _times.digestMinutes;
    var sunday = _at(DateTime.now(), dm ~/ 60, dm % 60);
    while (sunday.weekday != _times.digestWeekday || !sunday.isAfter(now)) {
      sunday = _at(sunday.add(const Duration(days: 1)), dm ~/ 60, dm % 60);
    }
    await _plugin.zonedSchedule(
      id: _digestId,
      title: 'Your predictions this week',
      body: [
        for (final c in undated.take(4)) '${c.label}: ${c.headline}',
      ].join('\n'),
      scheduledDate: sunday,
      notificationDetails: _digestDetails,
      androidScheduleMode: _mode,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Reminders for the working days after the next one, from each weekday's
  /// own trip history, so they still arrive if the app is not opened.
  static Future<void> _applyLeavePlan() async {
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
        await _plugin.zonedSchedule(
          id: _planEveningBaseId + slot,
          title: 'Leave for work',
          body: 'Tomorrow leave at $time to arrive on time.',
          scheduledDate: evening,
          notificationDetails: _commuteDetails,
          androidScheduleMode: _mode,
        );
      }
      if (nowAt.isAfter(now)) {
        await _plugin.zonedSchedule(
          id: _planLeaveNowBaseId + slot,
          title: 'Leave for work in 10 minutes',
          body: 'Leave at $time to arrive on time.',
          scheduledDate: nowAt,
          notificationDetails: _commuteDetails,
          androidScheduleMode: _mode,
        );
      }
      slot++;
    }
  }

  /// "Leave in 10 minutes", sent shortly before the predicted departure.
  static Future<void> _scheduleLeaveNow(
    PredictionCardData card,
    DateTime date,
  ) async {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(card.headline);
    if (match == null) return;
    final leave = _at(
      date,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
    final at = leave.subtract(const Duration(minutes: 10));
    if (!at.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id: _leaveNowId,
      title: 'Leave for work in 10 minutes',
      body: 'Leave at ${card.headline} to arrive on time. ${card.detail}',
      scheduledDate: at,
      notificationDetails: _commuteDetails,
      androidScheduleMode: _mode,
    );
  }

  static Future<void> _applyOdometer(bool enabled) async {
    for (var i = 0; i < _odometerMonths; i++) {
      await _plugin.cancel(id: _odometerBaseId + i);
    }
    await _plugin.cancel(id: _odometerNudgeId);
    final logged = _odometerLogged;
    if (!enabled || logged == null) return;

    final now = tz.TZDateTime.now(tz.local);
    const body = 'Log your bike odometer so service and oil timing stay exact.';
    final details = _details('odometer', 'Odometer log');

    final om = _times.odometerMinutes;

    // The 1st of each coming month, at the chosen time.
    for (var m = 1; m <= _odometerMonths; m++) {
      await _plugin.zonedSchedule(
        id: _odometerBaseId + m - 1,
        title: 'Log your odometer',
        body: body,
        scheduledDate: _at(DateTime(now.year, now.month + m, 1), om ~/ 60, om % 60),
        notificationDetails: details,
        androidScheduleMode: _mode,
      );
    }

    // This month still unlogged: an evening nudge until it is.
    if (!logged) {
      var at = _at(DateTime.now(), 20);
      if (!at.isAfter(now)) at = _at(at.add(const Duration(days: 1)), 20);
      await _plugin.zonedSchedule(
        id: _odometerNudgeId,
        title: 'Odometer not logged this month',
        body: body,
        scheduledDate: at,
        notificationDetails: details,
        androidScheduleMode: _mode,
      );
    }
  }
}
