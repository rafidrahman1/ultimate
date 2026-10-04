import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:health/health.dart';

import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/timeline_profile.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/prefs.dart';

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

  /// Where cache files live; tests point this at a temp directory.
  @visibleForTesting
  static Future<Directory> Function()? directoryOverride;

  Directory? _directory;
  final Map<String, Future<void>> _pendingWrites = {};

  Future<File> _fileFor(String key) async {
    final override = directoryOverride;
    var dir = override != null ? await override() : _directory;
    if (dir == null) {
      final base = await getApplicationSupportDirectory();
      dir = Directory('${base.path}${Platform.pathSeparator}data_cache');
      _directory = dir;
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$key.json');
  }

  /// Reads a cache entry from its file. Entries written by older builds live
  /// in SharedPreferences; those are moved to a file on first read.
  Future<Map<String, dynamic>?> _readMap(String key) async {
    await _pendingWrites[key];
    final file = await _fileFor(key);
    if (await file.exists()) {
      final decoded = await _decode(key, await file.readAsString());
      if (decoded == null) await _deleteQuietly(file);
      return decoded;
    }

    final prefs = await safePrefs();
    final legacy = prefs?.getString(key);
    if (legacy == null || legacy.isEmpty) return null;
    final decoded = await _decode(key, legacy);
    if (decoded != null) await _writeRaw(key, legacy);
    await prefs!.remove(key);
    return decoded;
  }

  Future<Map<String, dynamic>?> _decode(String key, String raw) async {
    if (raw.isEmpty) return null;
    try {
      // Location/expense history can be megabytes; keep it off the UI thread.
      final decoded = await Isolate.run(() => jsonDecode(raw));
      if (decoded is Map<String, dynamic>) return decoded;
      AppLog.warn('Cache entry $key is not a JSON object; clearing it.');
    } catch (error) {
      AppLog.warn('Cache entry $key is corrupt; clearing it: $error');
    }
    return null;
  }

  Future<void> _writeMap(String key, Map<String, dynamic> value) async {
    final raw = await Isolate.run(() => jsonEncode(value));
    await _writeRaw(key, raw);
  }

  /// Writes via a temp file + rename so a crash mid-write can't leave a
  /// truncated cache, and serializes writes per key.
  Future<void> _writeRaw(String key, String raw) {
    final previous = _pendingWrites[key] ?? Future<void>.value();
    final next = previous.then((_) async {
      try {
        final file = await _fileFor(key);
        final temp = File('${file.path}.tmp');
        await temp.writeAsString(raw, flush: true);
        await temp.rename(file.path);
      } catch (error) {
        AppLog.warn('Failed to write cache entry $key: $error');
      }
    });
    _pendingWrites[key] = next;
    return next;
  }

  Future<void> _remove(String key) async {
    await _pendingWrites[key];
    await _deleteQuietly(await _fileFor(key));
    final prefs = await safePrefs();
    await prefs?.remove(key);
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (error) {
      AppLog.warn('Failed to delete cache file ${file.path}: $error');
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
  'profile': _profileToJson(summary.profile),
  'trips': summary.trips.map(_tripToJson).toList(),
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
  final tripItems = json['trips'];
  final trips = tripItems is List
      ? tripItems
            .whereType<Map>()
            .map((e) => _tripFromJson(e.cast<String, dynamic>()))
            .toList()
      : <TimelineTrip>[];
  final profileJson = json['profile'];
  return LocationSummary(
    activities: activities,
    placeVisits: placeVisits,
    profile: profileJson is Map
        ? _profileFromJson(profileJson.cast<String, dynamic>())
        : LocationProfile.empty,
    trips: trips,
    fileName: json['fileName'] as String?,
  );
}

String? _pointToJson(GeoPoint? p) =>
    p == null ? null : '${p.latitude},${p.longitude}';

Map<String, dynamic> _profileToJson(LocationProfile profile) => {
  'places': [
    for (final p in profile.places)
      {'id': p.placeId, 'at': _pointToJson(p.point), 'label': p.label},
  ],
  'trips': [
    for (final t in profile.trips)
      {
        'dir': t.direction.name,
        'wd': t.weekday,
        'start': t.startMinutes,
        'mins': t.durationMinutes,
        'conf': t.confidence,
        'modes': t.modeShares,
      },
  ],
  'affinities': profile.modeAffinities,
};

LocationProfile _profileFromJson(Map<String, dynamic> json) {
  final places = <ProfilePlace>[];
  for (final item in (json['places'] as List?) ?? const []) {
    if (item is! Map) continue;
    final point = parseGeoPoint(item['at']);
    final id = item['id'] as String?;
    if (point == null || id == null) continue;
    places.add(
      ProfilePlace(placeId: id, point: point, label: item['label'] as String?),
    );
  }
  final trips = <FrequentTrip>[];
  for (final item in (json['trips'] as List?) ?? const []) {
    if (item is! Map) continue;
    final modes = <String, double>{};
    final rawModes = item['modes'];
    if (rawModes is Map) {
      rawModes.forEach((k, v) {
        if (v is num) modes[k.toString()] = v.toDouble();
      });
    }
    trips.add(
      FrequentTrip(
        direction: CommuteDirection.values.firstWhere(
          (d) => d.name == item['dir'],
          orElse: () => CommuteDirection.other,
        ),
        weekday: (item['wd'] as num?)?.toInt() ?? DateTime.monday,
        startMinutes: (item['start'] as num?)?.toInt() ?? 0,
        durationMinutes: (item['mins'] as num?)?.toInt() ?? 0,
        confidence: (item['conf'] as num?)?.toDouble(),
        modeShares: modes,
      ),
    );
  }
  final affinities = <String, double>{};
  final rawAffinities = json['affinities'];
  if (rawAffinities is Map) {
    rawAffinities.forEach((k, v) {
      if (v is num) affinities[k.toString()] = v.toDouble();
    });
  }
  return LocationProfile(
    places: places,
    trips: trips,
    modeAffinities: affinities,
  );
}

Map<String, dynamic> _tripToJson(TimelineTrip trip) => {
  'start': trip.startTime.toIso8601String(),
  'end': trip.endTime.toIso8601String(),
  'km': trip.distanceFromOriginKm,
  'places': trip.destinationPlaceIds,
};

TimelineTrip _tripFromJson(Map<String, dynamic> json) => TimelineTrip(
  startTime: DateTime.parse(json['start'] as String),
  endTime: DateTime.parse(json['end'] as String),
  distanceFromOriginKm: (json['km'] as num?)?.toInt() ?? 0,
  destinationPlaceIds: [
    for (final id in (json['places'] as List?) ?? const [])
      if (id is String) id,
  ],
);

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
  'placeId': visit.placeId,
  'at': _pointToJson(visit.point),
  'level': visit.level,
  'probability': visit.probability,
};

TimelinePlaceVisit _placeVisitFromJson(Map<String, dynamic> json) {
  return TimelinePlaceVisit(
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    name: json['name'] as String? ?? 'Unknown place',
    address: json['address'] as String?,
    semanticType: json['semanticType'] as String?,
    placeId: json['placeId'] as String?,
    point: parseGeoPoint(json['at']),
    level: (json['level'] as num?)?.toInt() ?? 0,
    probability: (json['probability'] as num?)?.toDouble(),
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
            .map((e) => HealthDataPoint.fromJson(e.cast<String, dynamic>()))
            .toList()
      : <HealthDataPoint>[];

  final periodStart = DateTime.parse(json['periodStart'] as String);
  final periodEnd = DateTime.parse(json['periodEnd'] as String);
  final dayCount =
      json['dayCount'] as int? ??
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
