import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/json_file_cache.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';

const _cacheKey = 'data_cache_game_activity_v1';

/// Persists the last-loaded game activity so it survives app restarts.
abstract final class GameActivityCache {
  static Future<GameActivitySummary?> load() async {
    final map = await JsonFileCache.instance.read(_cacheKey);
    if (map == null) return null;
    try {
      return _gameActivityFromJson(map);
    } catch (e) {
      AppLog.warn('Failed to load game activity cache: $e');
      return null;
    }
  }

  static Future<void> save(GameActivitySummary summary) async {
    if (summary.sessions.isEmpty) return;
    await JsonFileCache.instance.write(_cacheKey, _gameActivityToJson(summary));
  }

  static Future<void> clear() => JsonFileCache.instance.remove(_cacheKey);
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
