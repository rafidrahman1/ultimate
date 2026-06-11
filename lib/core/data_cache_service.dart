import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/core/app_log.dart';

const _expensesCacheKey = 'data_cache_expenses_v1';
const _locationCacheKey = 'data_cache_location_v1';
const _gameActivityCacheKey = 'data_cache_game_activity_v1';
const _calendarCacheKey = 'data_cache_calendar_v1';
const _monthlyHealthCacheKey = 'data_cache_monthly_health_v5';

/// Persists loaded feature data so it survives app restarts.
class DataCacheService {
  DataCacheService._();

  static final DataCacheService instance = DataCacheService._();

  Future<ExpensesSummary?> loadExpenses() async {
    final map = await _readMap(_expensesCacheKey);
    if (map == null) return null;
    try {
      return _expensesFromJson(map);
    } catch (e) {
      AppLog.warn('Failed to load expenses cache: $e');
      return null;
    }
  }

  Future<void> saveExpenses(ExpensesSummary summary) async {
    if (summary.transactions.isEmpty) return;
    await _writeMap(_expensesCacheKey, _expensesToJson(summary));
  }

  Future<void> clearExpenses() => _remove(_expensesCacheKey);

  Future<LocationSummary?> loadLocation() async {
    final map = await _readMap(_locationCacheKey);
    if (map == null) return null;
    try {
      return _locationFromJson(map);
    } catch (e) {
      AppLog.warn('Failed to load location cache: $e');
      return null;
    }
  }

  Future<void> saveLocation(LocationSummary summary) async {
    if (summary.activities.isEmpty) return;
    await _writeMap(_locationCacheKey, _locationToJson(summary));
  }

  Future<void> clearLocation() => _remove(_locationCacheKey);

  Future<GameActivitySummary?> loadGameActivity() async {
    final map = await _readMap(_gameActivityCacheKey);
    if (map == null) return null;
    try {
      return _gameActivityFromJson(map);
    } catch (e) {
      AppLog.warn('Failed to load game activity cache: $e');
      return null;
    }
  }

  Future<void> saveGameActivity(GameActivitySummary summary) async {
    if (summary.sessions.isEmpty) return;
    await _writeMap(_gameActivityCacheKey, _gameActivityToJson(summary));
  }

  Future<void> clearGameActivity() => _remove(_gameActivityCacheKey);

  Future<CalendarSummary?> loadCalendar() async {
    final map = await _readMap(_calendarCacheKey);
    if (map == null) return null;
    try {
      return _calendarFromJson(map);
    } catch (e) {
      AppLog.warn('Failed to load calendar cache: $e');
      return null;
    }
  }

  Future<void> saveCalendar(CalendarSummary summary) async {
    if (summary.events.isEmpty) return;
    await _writeMap(_calendarCacheKey, _calendarToJson(summary));
  }

  Future<void> clearCalendar() => _remove(_calendarCacheKey);

  Future<MonthlyHealthFetchResult?> loadMonthlyHealth() async {
    final map = await _readMap(_monthlyHealthCacheKey);
    if (map == null) return null;
    try {
      return _monthlyHealthFromJson(map);
    } catch (e) {
      AppLog.warn('Failed to load monthly health cache: $e');
      return null;
    }
  }

  Future<void> saveMonthlyHealth(MonthlyHealthFetchResult result) async {
    if (!result.hasData) return;
    await _writeMap(_monthlyHealthCacheKey, _monthlyHealthToJson(result));
  }

  Future<void> clearMonthlyHealth() => _remove(_monthlyHealthCacheKey);

  Future<Map<String, dynamic>?> _readMap(String key) async {
    final prefs = await _safePrefs();
    if (prefs == null) return null;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  }

  Future<void> _writeMap(String key, Map<String, dynamic> value) async {
    final prefs = await _safePrefs();
    if (prefs == null) return;
    await prefs.setString(key, jsonEncode(value));
  }

  Future<void> _remove(String key) async {
    final prefs = await _safePrefs();
    if (prefs == null) return;
    await prefs.remove(key);
  }

  Future<SharedPreferences?> _safePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on PlatformException catch (error) {
      AppLog.warn('SharedPreferences channel error: $error');
      return null;
    } catch (error) {
      AppLog.warn('SharedPreferences init failed: $error');
      return null;
    }
  }
}

Map<String, dynamic> _expensesToJson(ExpensesSummary summary) => {
      'fileName': summary.fileName,
      'transactions': summary.transactions.map(_transactionToJson).toList(),
    };

ExpensesSummary _expensesFromJson(Map<String, dynamic> json) {
  final items = json['transactions'];
  final transactions = items is List
      ? items
          .whereType<Map>()
          .map((e) => _transactionFromJson(e.cast<String, dynamic>()))
          .toList()
      : <CashewTransaction>[];
  return ExpensesSummary(
    transactions: transactions,
    fileName: json['fileName'] as String?,
  );
}

Map<String, dynamic> _transactionToJson(CashewTransaction tx) => {
      'account': tx.account,
      'amount': tx.amount,
      'currency': tx.currency,
      'date': tx.date.toIso8601String(),
      'isIncome': tx.isIncome,
      'title': tx.title,
      'note': tx.note,
      'category': tx.category,
      'subcategory': tx.subcategory,
    };

CashewTransaction _transactionFromJson(Map<String, dynamic> json) {
  final dateRaw = json['date'] as String?;
  final date = dateRaw == null ? DateTime.now() : DateTime.parse(dateRaw);
  return CashewTransaction(
    account: json['account'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    currency: json['currency'] as String? ?? '',
    date: date,
    isIncome: json['isIncome'] as bool? ?? false,
    title: json['title'] as String?,
    note: json['note'] as String?,
    category: json['category'] as String?,
    subcategory: json['subcategory'] as String?,
  );
}

Map<String, dynamic> _locationToJson(LocationSummary summary) => {
      'fileName': summary.fileName,
      'activities': summary.activities.map(_activityToJson).toList(),
      'placeVisits': summary.placeVisits.map(_placeVisitToJson).toList(),
    };

LocationSummary _locationFromJson(Map<String, dynamic> json) {
  final items = json['activities'];
  final activities = items is List
      ? items
          .whereType<Map>()
          .map((e) => _activityFromJson(e.cast<String, dynamic>()))
          .toList()
      : <TimelineActivity>[];
  final placeItems = json['placeVisits'];
  final placeVisits = placeItems is List
      ? placeItems
          .whereType<Map>()
          .map((e) => _placeVisitFromJson(e.cast<String, dynamic>()))
          .toList()
      : <TimelinePlaceVisit>[];
  return LocationSummary(
    activities: activities,
    placeVisits: placeVisits,
    fileName: json['fileName'] as String?,
  );
}

Map<String, dynamic> _activityToJson(TimelineActivity activity) => {
      'startTime': activity.startTime.toIso8601String(),
      'endTime': activity.endTime.toIso8601String(),
      'type': activity.type,
      'distanceMeters': activity.distanceMeters,
      'probability': activity.probability,
    };

TimelineActivity _activityFromJson(Map<String, dynamic> json) {
  return TimelineActivity(
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    type: json['type'] as String? ?? '',
    distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
    probability: (json['probability'] as num?)?.toDouble(),
  );
}

Map<String, dynamic> _placeVisitToJson(TimelinePlaceVisit visit) => {
      'startTime': visit.startTime.toIso8601String(),
      'endTime': visit.endTime.toIso8601String(),
      'name': visit.name,
      'address': visit.address,
      'semanticType': visit.semanticType,
    };

TimelinePlaceVisit _placeVisitFromJson(Map<String, dynamic> json) {
  return TimelinePlaceVisit(
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    name: json['name'] as String? ?? 'Unknown place',
    address: json['address'] as String?,
    semanticType: json['semanticType'] as String?,
  );
}

Map<String, dynamic> _gameActivityToJson(GameActivitySummary summary) => {
      'fileName': summary.fileName,
      'sessions': summary.sessions.map(_sessionToJson).toList(),
    };

GameActivitySummary _gameActivityFromJson(Map<String, dynamic> json) {
  final items = json['sessions'];
  final sessions = items is List
      ? items
          .whereType<Map>()
          .map((e) => _sessionFromJson(e.cast<String, dynamic>()))
          .toList()
      : <GameActivitySession>[];
  return GameActivitySummary(
    sessions: sessions,
    fileName: json['fileName'] as String?,
  );
}

Map<String, dynamic> _sessionToJson(GameActivitySession session) => {
      'name': session.name,
      'sessionDate': session.sessionDate.toIso8601String(),
      'timePlayedSeconds': session.timePlayed.inSeconds,
    };

GameActivitySession _sessionFromJson(Map<String, dynamic> json) {
  return GameActivitySession(
    name: json['name'] as String? ?? '',
    sessionDate: DateTime.parse(json['sessionDate'] as String),
    timePlayed: Duration(seconds: json['timePlayedSeconds'] as int? ?? 0),
  );
}

Map<String, dynamic> _calendarToJson(CalendarSummary summary) => {
      'events': summary.events.map(_calendarEventToJson).toList(),
      'accountEmail': summary.accountEmail,
      'accountDisplayName': summary.accountDisplayName,
      'accountPhotoUrl': summary.accountPhotoUrl,
      'syncedAt': summary.syncedAt?.toIso8601String(),
      'rangeStart': summary.rangeStart?.toIso8601String(),
      'rangeEnd': summary.rangeEnd?.toIso8601String(),
    };

CalendarSummary _calendarFromJson(Map<String, dynamic> json) {
  final items = json['events'];
  final events = items is List
      ? items
          .whereType<Map>()
          .map((e) => _calendarEventFromJson(e.cast<String, dynamic>()))
          .toList()
      : <CalendarEvent>[];
  return CalendarSummary(
    events: events,
    accountEmail: json['accountEmail'] as String?,
    accountDisplayName: json['accountDisplayName'] as String?,
    accountPhotoUrl: json['accountPhotoUrl'] as String?,
    syncedAt: _parseOptionalDate(json['syncedAt'] as String?),
    rangeStart: _parseOptionalDate(json['rangeStart'] as String?),
    rangeEnd: _parseOptionalDate(json['rangeEnd'] as String?),
  );
}

Map<String, dynamic> _calendarEventToJson(CalendarEvent event) => {
      'title': event.title,
      'start': event.start.toIso8601String(),
      'end': event.end.toIso8601String(),
      'allDay': event.allDay,
      'location': event.location,
      'isHoliday': event.isHoliday,
    };

CalendarEvent _calendarEventFromJson(Map<String, dynamic> json) {
  return CalendarEvent(
    title: json['title'] as String? ?? '',
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    allDay: json['allDay'] as bool? ?? false,
    location: json['location'] as String?,
    isHoliday: json['isHoliday'] as bool? ?? false,
  );
}

Map<String, dynamic> _monthlyHealthToJson(MonthlyHealthFetchResult result) => {
      'cachedAt': DateTime.now().toIso8601String(),
      'periodStart': result.periodStart.toIso8601String(),
      'periodEnd': result.periodEnd.toIso8601String(),
      'dayCount': result.dayCount,
      'points': result.points.map((p) => p.toJson()).toList(),
    };

MonthlyHealthFetchResult _monthlyHealthFromJson(Map<String, dynamic> json) {
  final pointsRaw = json['points'];
  final points = pointsRaw is List
      ? pointsRaw
          .whereType<Map>()
          .map(
            (e) => HealthDataPoint.fromJson(e.cast<String, dynamic>()),
          )
          .toList()
      : <HealthDataPoint>[];

  final periodStart = DateTime.parse(json['periodStart'] as String);
  final periodEnd = DateTime.parse(json['periodEnd'] as String);
  final dayCount = json['dayCount'] as int? ??
      DateTime(periodStart.year, periodStart.month + 1, 0).day;

  return MonthlyHealthFetchResult(
    points: points,
    periodStart: periodStart,
    periodEnd: periodEnd,
    dayCount: dayCount,
  );
}

DateTime? _parseOptionalDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.parse(raw);
}
