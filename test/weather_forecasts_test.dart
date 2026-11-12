import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/forecasts/life/life_forecasts_commute.dart';
import 'package:personal/features/forecasts/life/life_forecasts_weather.dart';
import 'package:personal/features/weather/data/weather_models.dart';

void main() {
  final now = DateTime(2026, 10, 20, 12);
  final today = DateTime(2026, 10, 20);

  WeatherDay day(
    int ahead, {
    int code = 0,
    double hi = 30,
    double mm = 0,
    double prob = 0,
    double wind = 10,
  }) => WeatherDay(
    date: today.add(Duration(days: ahead)),
    code: code,
    tempMax: hi,
    tempMin: hi - 8,
    precipMm: mm,
    precipProbability: prob,
    windMaxKmh: wind,
    uvMax: 6,
  );

  WeatherForecast forecast(List<WeatherDay> days) => WeatherForecast(
    fetchedAt: now,
    latitude: 23.8,
    longitude: 90.4,
    days: days,
  );

  test('parses an Open-Meteo daily response and skips broken days', () {
    final parsed = parseOpenMeteo({
      'latitude': 23.8,
      'longitude': 90.4,
      'daily': {
        'time': ['2026-10-20', '2026-10-21', '2026-10-22'],
        'weather_code': [0, 63, 3],
        'temperature_2m_max': [31.2, 28.0, null],
        'temperature_2m_min': [24.0, 23.0, 22.0],
        'precipitation_sum': [0.0, 12.4, 0.0],
        'precipitation_probability_max': [5, 90, 10],
        'wind_speed_10m_max': [12.0, 25.0, 8.0],
        'uv_index_max': [8.0, 3.0, 5.0],
      },
    }, fetchedAt: now);
    expect(parsed!.days, hasLength(2));
    expect(parsed.on(today)!.summary, 'Clear');
    expect(parsed.days[1].isWet, isTrue);
    expect(parseOpenMeteo({'error': true}, fetchedAt: now), isNull);
  });

  test('round trips through json', () {
    final f = forecast([day(0), day(1, code: 63, mm: 9, prob: 80)]);
    final back = WeatherForecast.fromJson(f.toJson());
    expect(back.days[1].isWet, isTrue);
    expect(back.days[1].precipMm, 9);
  });

  test('weather ahead is skipped without a forecast', () {
    expect(forecastWeatherAhead(LifeInputs(now: now)), isNull);
    expect(
      forecastWeatherAhead(
        LifeInputs(now: now, weather: forecast([day(0), day(1)])),
      ),
      isNull,
    );
  });

  test('weather ahead flags heavy rain tomorrow', () {
    final f = forecastWeatherAhead(
      LifeInputs(
        now: now,
        weather: forecast([
          day(0),
          day(1, code: 65, mm: 30, prob: 95),
          for (var d = 2; d < 7; d++) day(d),
        ]),
      ),
    )!;
    expect(f.headline, 'Heavy rain tomorrow');
    expect(f.attention, isTrue);
    expect(f.detail, contains('1 of the next 7 days'));
  });

  test('a dry mild week is calm and names an outdoor day', () {
    final f = forecastWeatherAhead(
      LifeInputs(
        now: now,
        weather: forecast([for (var d = 0; d < 7; d++) day(d)]),
      ),
    )!;
    expect(f.headline, 'Dry week');
    expect(f.attention, isFalse);
    expect(f.detail, contains('best day outside'));
  });

  test('outdoor penalty rises with rain and heat', () {
    expect(day(0).outdoorPenalty, lessThan(0.1));
    expect(
      day(0, code: 63, mm: 20, prob: 90).outdoorPenalty,
      greaterThan(day(0, hi: 38).outdoorPenalty),
    );
  });

  test('weather rows list the days from today', () {
    final rows = weatherRows(
      LifeInputs(now: now, weather: forecast([day(-1), day(0), day(1)])),
    );
    expect(rows.split('\n'), hasLength(3));
  });

  test('commute helper is exported for the planner', () {
    expect(commuteSamples(LifeInputs(now: now)), isEmpty);
  });

  test('bike wash picks a dry day that stays dry after', () {
    final f = forecastBikeWash(
      LifeInputs(
        now: now,
        weather: forecast([
          day(0, code: 63, mm: 12, prob: 90),
          day(1, code: 63, mm: 8, prob: 80),
          day(2),
          day(3),
          day(4),
          day(5, code: 63, mm: 10, prob: 90),
          day(6),
        ]),
      ),
    )!;
    expect(
      f.headline,
      'Wash ${weekdayShort(today.add(const Duration(days: 2)))}',
    );
  });

  test('bike wash says wait when it rains every day', () {
    final f = forecastBikeWash(
      LifeInputs(
        now: now,
        weather: forecast([
          for (var d = 0; d < 7; d++) day(d, code: 63, mm: 10, prob: 90),
        ]),
      ),
    )!;
    expect(f.headline, 'Wait, rain around');
  });
}
