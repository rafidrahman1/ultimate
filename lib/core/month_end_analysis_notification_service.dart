import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../features/results/insights_parser.dart';
import '../features/results/results_service.dart';
import 'analysis_period.dart';
import 'analysis_reports_storage.dart';

const _monthEndReminderEnabledKey = 'month_end_analysis_reminder_enabled_v1';
const _weekEndChecklistReminderEnabledKey =
    'week_end_checklist_reminder_enabled_v1';
const _selectedChecklistResultIdKey = 'home_checklist_result_id_v1';
const _insightChecklistPrefix = 'insight_checklist_v1_';

class MonthEndAnalysisNotificationService {
  MonthEndAnalysisNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _baseNotificationId = 9800;
  static const int _baseWeekEndNotificationId = 9900;
  static const int _monthsToSchedule = 12;
  static const int _maxWeekEndNotifications = 8;
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

    final weekEndEnabled = await isWeekEndChecklistReminderEnabled();
    if (weekEndEnabled) {
      await _scheduleWeekEndChecklistReminders();
    } else {
      await _cancelWeekEndReminders();
    }
  }

  static Future<bool> isWeekEndChecklistReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_weekEndChecklistReminderEnabledKey) ?? true;
  }

  static Future<void> setWeekEndChecklistReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_weekEndChecklistReminderEnabledKey, enabled);
    await scheduleFromSettings();
  }

  static Future<void> _configureTimezone() async {
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (error) {
      debugPrint('Timezone init failed, falling back to UTC: $error');
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

  static Future<void> _cancelWeekEndReminders() async {
    for (var i = 0; i < _maxWeekEndNotifications; i++) {
      await _plugin.cancel(id: _baseWeekEndNotificationId + i);
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

  static Future<void> _scheduleWeekEndChecklistReminders() async {
    await _cancelWeekEndReminders();
    final prefs = await SharedPreferences.getInstance();
    final selectedResultId = prefs.getString(_selectedChecklistResultIdKey);
    if (selectedResultId == null || selectedResultId.isEmpty) return;

    List<AnalysisResult> storedResults;
    try {
      final rawResults = await AnalysisReportsStorage.instance.loadAll();
      storedResults = rawResults.map(AnalysisResult.fromJson).toList();
    } catch (_) {
      return;
    }

    AnalysisResult? result;
    for (final item in storedResults) {
      if (item.id == selectedResultId) {
        result = item;
        break;
      }
    }
    if (result == null) return;

    final report = InsightParser.parse(result.output);
    if (report.actions.isEmpty) return;

    final period = AnalysisPeriod.forReference(result.createdAt);
    final now = tz.TZDateTime.now(tz.local);
    final totalWeeks = report.checklistWeekCount;
    var scheduledCount = 0;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'week_end_checklist',
        'Week-end checklist reminders',
        channelDescription:
            'Reminders when weekly checklist still has open items',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    for (var weekIndex = 0; weekIndex < totalWeeks; weekIndex++) {
      final actions = report.actionsForWeekIndex(weekIndex);
      if (actions.isEmpty) continue;

      final checked = _loadCheckedItems(
        prefs: prefs,
        resultId: selectedResultId,
        weekIndex: weekIndex,
      );
      if (checked.length >= actions.length) continue;

      final scheduledAt = _weekEndAt8Pm(period: period, weekIndex: weekIndex);
      if (!scheduledAt.isAfter(now)) continue;
      if (scheduledCount >= _maxWeekEndNotifications) break;

      await _plugin.zonedSchedule(
        id: _baseWeekEndNotificationId + scheduledCount,
        title: 'Weekly checklist pending',
        body:
            '${actions.length - checked.length} item(s) still unchecked this week.',
        scheduledDate: scheduledAt,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      scheduledCount++;
    }
  }

  static Set<int> _loadCheckedItems({
    required SharedPreferences prefs,
    required String resultId,
    required int weekIndex,
  }) {
    final raw = prefs.getString(
      '$_insightChecklistPrefix${resultId}_w$weekIndex',
    );
    if (raw == null || raw.isEmpty) return {};
    try {
      final parsed = jsonDecode(raw) as List<dynamic>;
      return parsed.map((value) => (value as num).toInt()).toSet();
    } catch (_) {
      return {};
    }
  }

  static tz.TZDateTime _weekEndAt8Pm({
    required AnalysisPeriod period,
    required int weekIndex,
  }) {
    if (weekIndex < period.checklistWeeks.length) {
      final week = period.checklistWeeks[weekIndex];
      return tz.TZDateTime(
        tz.local,
        week.end.year,
        week.end.month,
        week.end.day,
        20,
      );
    }

    final fallback = period.checklistMonthStart.add(
      Duration(days: weekIndex * 7 + 6),
    );
    return tz.TZDateTime(
      tz.local,
      fallback.year,
      fallback.month,
      fallback.day,
      20,
    );
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
