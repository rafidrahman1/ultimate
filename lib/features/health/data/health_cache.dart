import 'package:health/health.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/json_file_cache.dart';
import 'package:personal/features/health/data/health_service.dart';
import 'package:personal/features/health/data/vitals_models.dart';

const _cacheKey = 'data_cache_monthly_health_v5';

/// Persists the last-loaded monthly health so it survives app restarts.
abstract final class MonthlyHealthCache {
  static Future<MonthlyHealthFetchResult?> load() async {
    final map = await JsonFileCache.instance.read(_cacheKey);
    if (map == null) return null;
    try {
      return _monthlyHealthFromJson(map);
    } catch (e) {
      AppLog.warn('Failed to load monthly health cache: $e');
      return null;
    }
  }

  static Future<void> save(MonthlyHealthFetchResult result) async {
    if (!result.hasData) return;
    await JsonFileCache.instance.write(_cacheKey, _monthlyHealthToJson(result));
  }

  static Future<void> clear() => JsonFileCache.instance.remove(_cacheKey);
}

Map<String, dynamic> _monthlyHealthToJson(MonthlyHealthFetchResult result) => {
  'cachedAt': DateTime.now().toIso8601String(),
  'periodStart': result.periodStart.toIso8601String(),
  'periodEnd': result.periodEnd.toIso8601String(),
  'dayCount': result.dayCount,
  'points': result.points.map((p) => p.toJson()).toList(),
  'vitals': result.vitals?.toJson(),
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

  final vitalsRaw = json['vitals'];
  return MonthlyHealthFetchResult(
    points: points,
    periodStart: periodStart,
    periodEnd: periodEnd,
    dayCount: dayCount,
    vitals: vitalsRaw is Map
        ? VitalsSummary.fromJson(vitalsRaw.cast<String, dynamic>())
        : null,
  );
}
