/// One day of the forecast from Open-Meteo.
class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.code,
    required this.tempMax,
    required this.tempMin,
    required this.precipMm,
    required this.precipProbability,
    required this.windMaxKmh,
    required this.uvMax,
  });

  /// Local calendar day (midnight) at the forecast location.
  final DateTime date;

  /// WMO weather code.
  final int code;
  final double tempMax;
  final double tempMin;
  final double precipMm;

  /// Highest chance of rain that day, 0–100.
  final double precipProbability;
  final double windMaxKmh;
  final double uvMax;

  /// Rain is likely enough to plan around.
  bool get isWet =>
      precipProbability >= 60 || precipMm >= 5 || _stormy || _snowy;

  bool get isHeavyRain => precipMm >= 15 && precipProbability >= 50;
  bool get isHot => tempMax >= 36;
  bool get isWindy => windMaxKmh >= 40;
  bool get _stormy => code >= 95;
  bool get _snowy => (code >= 71 && code <= 77) || code == 85 || code == 86;

  /// 0 (perfect for being outside) to 1 (stay in). Rain dominates, then heat
  /// and wind.
  double get outdoorPenalty {
    var p = (precipProbability / 100) * 0.5 + (precipMm / 20).clamp(0, 0.4);
    if (tempMax >= 32) p += ((tempMax - 32) / 10).clamp(0, 0.4);
    if (tempMax <= 5) p += ((5 - tempMax) / 10).clamp(0, 0.3);
    if (windMaxKmh >= 30) p += ((windMaxKmh - 30) / 40).clamp(0, 0.2);
    return p.clamp(0, 1).toDouble();
  }

  String get summary => weatherCodeLabel(code);

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'code': code,
    'tMax': tempMax,
    'tMin': tempMin,
    'precip': precipMm,
    'prob': precipProbability,
    'wind': windMaxKmh,
    'uv': uvMax,
  };

  factory WeatherDay.fromJson(Map<String, dynamic> json) => WeatherDay(
    date: DateTime.parse(json['date'] as String),
    code: (json['code'] as num).toInt(),
    tempMax: (json['tMax'] as num).toDouble(),
    tempMin: (json['tMin'] as num).toDouble(),
    precipMm: (json['precip'] as num).toDouble(),
    precipProbability: (json['prob'] as num).toDouble(),
    windMaxKmh: (json['wind'] as num).toDouble(),
    uvMax: (json['uv'] as num).toDouble(),
  );
}

/// The forecast for the next days around one point.
class WeatherForecast {
  const WeatherForecast({
    required this.fetchedAt,
    required this.latitude,
    required this.longitude,
    required this.days,
  });

  final DateTime fetchedAt;
  final double latitude;
  final double longitude;
  final List<WeatherDay> days;

  bool get isEmpty => days.isEmpty;

  WeatherDay? on(DateTime day) {
    for (final d in days) {
      if (d.date.year == day.year &&
          d.date.month == day.month &&
          d.date.day == day.day) {
        return d;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'fetchedAt': fetchedAt.toIso8601String(),
    'lat': latitude,
    'lon': longitude,
    'days': [for (final d in days) d.toJson()],
  };

  factory WeatherForecast.fromJson(Map<String, dynamic> json) =>
      WeatherForecast(
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lon'] as num).toDouble(),
        days: [
          for (final d in json['days'] as List)
            WeatherDay.fromJson(d as Map<String, dynamic>),
        ],
      );
}

/// Plain-language label for a WMO weather code.
String weatherCodeLabel(int code) {
  if (code == 0) return 'Clear';
  if (code <= 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Fog';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code >= 61 && code <= 67) return 'Rain';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Showers';
  if (code == 85 || code == 86) return 'Snow showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Mixed';
}

/// Parses an Open-Meteo `/v1/forecast` response with `daily` arrays. Days with
/// a missing temperature are skipped; other missing values count as zero.
WeatherForecast? parseOpenMeteo(
  Map<String, dynamic> json, {
  required DateTime fetchedAt,
}) {
  final daily = json['daily'];
  if (daily is! Map) return null;
  final times = daily['time'];
  if (times is! List) return null;
  List<dynamic> col(String name) {
    final v = daily[name];
    return v is List ? v : const [];
  }

  double num0(List<dynamic> c, int i) =>
      i < c.length && c[i] is num ? (c[i] as num).toDouble() : 0;
  double? numN(List<dynamic> c, int i) =>
      i < c.length && c[i] is num ? (c[i] as num).toDouble() : null;

  final code = col('weather_code');
  final tMax = col('temperature_2m_max');
  final tMin = col('temperature_2m_min');
  final precip = col('precipitation_sum');
  final prob = col('precipitation_probability_max');
  final wind = col('wind_speed_10m_max');
  final uv = col('uv_index_max');

  final days = <WeatherDay>[];
  for (var i = 0; i < times.length; i++) {
    final date = DateTime.tryParse('${times[i]}');
    final hi = numN(tMax, i);
    final lo = numN(tMin, i);
    if (date == null || hi == null || lo == null) continue;
    days.add(
      WeatherDay(
        date: DateTime(date.year, date.month, date.day),
        code: num0(code, i).round(),
        tempMax: hi,
        tempMin: lo,
        precipMm: num0(precip, i),
        precipProbability: num0(prob, i),
        windMaxKmh: num0(wind, i),
        uvMax: num0(uv, i),
      ),
    );
  }
  if (days.isEmpty) return null;
  return WeatherForecast(
    fetchedAt: fetchedAt,
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    days: days,
  );
}
