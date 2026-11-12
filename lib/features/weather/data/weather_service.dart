import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/json_file_cache.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/location/data/location_service.dart';
import 'package:personal/features/location/data/timeline_profile.dart';
import 'package:personal/features/weather/data/weather_models.dart';

const _cacheKey = 'data_cache_weather_v1';
const _enabledPref = 'weather_enabled';
const _freshFor = Duration(hours: 3);

/// Coordinates are rounded to this many decimals (about 11 km) before they
/// leave the device; a forecast does not need your exact address.
const _coordinateDecimals = 1;

double _round(double v) {
  final f = _pow10(_coordinateDecimals);
  return (v * f).round() / f;
}

double _pow10(int n) => n == 0 ? 1 : 10 * _pow10(n - 1);

/// Whether the app may ask Open-Meteo for the weather. On by default; the
/// only thing sent is your home area, rounded to about 11 km.
final weatherEnabledProvider = NotifierProvider<WeatherEnabledNotifier, bool>(
  WeatherEnabledNotifier.new,
);

class WeatherEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await safePrefs();
    final saved = prefs?.getBool(_enabledPref);
    if (saved != null && saved != state) state = saved;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await safePrefs();
    await prefs?.setBool(_enabledPref, value);
  }
}

/// Where the forecast is for: the home point from Timeline, else the place you
/// were last recorded at home. Null until location data is imported.
final weatherPointProvider = Provider<GeoPoint?>((ref) {
  final location = ref.watch(locationSummaryProvider);
  final home = location.profile.home;
  if (home != null) return home;
  GeoPoint? point;
  DateTime? latest;
  for (final v in location.placeVisits) {
    if (!v.isHome && !v.isInferredHome) continue;
    final p = v.point;
    if (p == null) continue;
    if (latest == null || v.endTime.isAfter(latest)) {
      latest = v.endTime;
      point = p;
    }
  }
  return point;
});

/// The 14-day forecast for [weatherPointProvider], cached for a few hours.
final weatherProvider = FutureProvider<WeatherForecast?>((ref) async {
  if (!ref.watch(weatherEnabledProvider)) return null;
  final point = ref.watch(weatherPointProvider);
  if (point == null) return null;
  return WeatherService().load(
    latitude: _round(point.latitude),
    longitude: _round(point.longitude),
  );
});

class WeatherService {
  WeatherService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<WeatherForecast?> load({
    required double latitude,
    required double longitude,
  }) async {
    final cached = await _readCache();
    final sameSpot =
        cached != null &&
        (cached.latitude - latitude).abs() < 0.05 &&
        (cached.longitude - longitude).abs() < 0.05;
    if (sameSpot && clock.now().difference(cached.fetchedAt) < _freshFor) {
      return cached;
    }
    final fresh = await _fetch(latitude, longitude);
    if (fresh != null) {
      await JsonFileCache.instance.write(_cacheKey, fresh.toJson());
      return fresh;
    }
    // Offline: yesterday's outlook still beats none, but only for days ahead.
    return sameSpot ? cached : null;
  }

  Future<WeatherForecast?> _readCache() async {
    try {
      final map = await JsonFileCache.instance.read(_cacheKey);
      return map == null ? null : WeatherForecast.fromJson(map);
    } catch (e) {
      AppLog.warn('Failed to load weather cache: $e');
      return null;
    }
  }

  Future<WeatherForecast?> _fetch(double latitude, double longitude) async {
    final client = _client ?? http.Client();
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,'
            'precipitation_sum,precipitation_probability_max,'
            'wind_speed_10m_max,uv_index_max',
        'timezone': 'auto',
        'forecast_days': '14',
      });
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        AppLog.warn('Weather request failed: ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return parseOpenMeteo(decoded, fetchedAt: clock.now());
    } catch (e) {
      AppLog.warn('Weather request failed: $e');
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }
}
