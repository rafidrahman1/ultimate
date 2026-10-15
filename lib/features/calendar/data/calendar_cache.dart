import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/json_file_cache.dart';
import 'package:personal/features/calendar/data/calendar_event.dart';

const _cacheKey = 'data_cache_calendar_v1';

/// Persists the last-loaded calendar so it survives app restarts.
abstract final class CalendarCache {
  static Future<CalendarSummary?> load() async {
    final map = await JsonFileCache.instance.read(_cacheKey);
    if (map == null) return null;
    try {
      return _calendarFromJson(map);
    } catch (e) {
      AppLog.warn('Failed to load calendar cache: $e');
      return null;
    }
  }

  static Future<void> save(CalendarSummary summary) async {
    if (summary.events.isEmpty) return;
    await JsonFileCache.instance.write(_cacheKey, _calendarToJson(summary));
  }

  static Future<void> clear() => JsonFileCache.instance.remove(_cacheKey);
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

DateTime? _parseOptionalDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.parse(raw);
}
