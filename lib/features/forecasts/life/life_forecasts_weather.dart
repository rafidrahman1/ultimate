import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/forecasts/life/life_raw_data.dart';
import 'package:personal/features/weather/data/weather_models.dart';

/// Forecast rows for AI prompts, one per day from today.
String weatherRows(LifeInputs i) {
  final w = i.weather;
  if (w == null || w.isEmpty) return '- no weather forecast';
  return [
    'date | conditions | high C | low C | rain mm | rain chance % | wind km/h | UV',
    for (final d in w.days)
      if (!d.date.isBefore(i.today))
        '${dateLine.format(d.date)} | ${d.summary} | '
            '${d.tempMax.round()} | ${d.tempMin.round()} | '
            '${d.precipMm.toStringAsFixed(1)} | ${d.precipProbability.round()} | '
            '${d.windMaxKmh.round()} | ${d.uvMax.round()}',
  ].join('\n');
}

/// One short line about the weather on [day], or '' when unknown.
String weatherNote(LifeInputs i, DateTime day) {
  final d = i.weather?.on(day);
  if (d == null) return '';
  final rain = d.isWet
      ? ', ${d.precipProbability.round()}% chance of rain'
      : '';
  return '${d.summary}, ${d.tempMax.round()}°$rain';
}

/// What the next week looks like outside: the wet, hot and windy days to plan
/// around, and the day best suited to being outdoors.
LifeForecast? forecastWeatherAhead(LifeInputs i) {
  final w = i.weather;
  if (w == null) return null;
  final week = [
    for (final d in w.days)
      if (!d.date.isBefore(i.today)) d,
  ].take(7).toList();
  if (week.length < 3) return null;

  final wet = [
    for (final d in week)
      if (d.isWet) d,
  ];
  final hot = [
    for (final d in week)
      if (d.isHot) d,
  ];
  final windy = [
    for (final d in week)
      if (d.isWindy) d,
  ];
  final storms = [
    for (final d in week)
      if (d.code >= 95) d,
  ];
  final heavy = [
    for (final d in week)
      if (d.isHeavyRain) d,
  ];
  final hottest = week.reduce((a, b) => a.tempMax >= b.tempMax ? a : b);
  final wettest = week.reduce((a, b) => a.precipMm >= b.precipMm ? a : b);
  final best = week.reduce(
    (a, b) => a.outdoorPenalty <= b.outdoorPenalty ? a : b,
  );
  final goodOutdoors = best.outdoorPenalty <= 0.45;
  final soon = week.where((d) => d.date.difference(i.today).inDays <= 1);
  final urgent = [
    for (final d in soon)
      if (d.isHeavyRain || d.code >= 95 || d.tempMax >= 38) d,
  ];

  String day(WeatherDay d) => d.date == i.today
      ? 'today'
      : d.date.difference(i.today).inDays == 1
      ? 'tomorrow'
      : weekdayShort(d.date);

  final String headline;
  final DateTime? date;
  if (storms.isNotEmpty) {
    headline = 'Storm ${day(storms.first)}';
    date = storms.first.date;
  } else if (heavy.isNotEmpty) {
    headline = 'Heavy rain ${day(heavy.first)}';
    date = heavy.first.date;
  } else if (hot.isNotEmpty) {
    headline = 'Hot ${day(hottest)}, ${hottest.tempMax.round()}°';
    date = hottest.date;
  } else if (wet.isNotEmpty) {
    headline = 'Rain ${day(wet.first)}';
    date = wet.first.date;
  } else {
    headline = 'Dry week';
    date = null;
  }

  final parts = <String>[
    wet.isEmpty
        ? 'No rain likely in the next ${week.length} days'
        : '${wet.length} of the next ${week.length} days look wet '
              '(${wet.map((d) => weekdayShort(d.date)).join(', ')}), '
              'most on ${weekdayShort(wettest.date)} with '
              '${wettest.precipMm.toStringAsFixed(0)} mm',
    'hottest ${day(hottest)} at ${hottest.tempMax.round()}°',
    if (goodOutdoors)
      'best day outside is ${day(best)} (${best.summary.toLowerCase()}, '
          '${best.tempMax.round()}°)'
    else
      'no day is really good for being outside',
  ];
  final detail = '${parts.join('; ')}.';

  return LifeForecast(
    kind: LifeForecastKind.weatherAhead,
    headline: headline,
    detail: detail,
    date: date,
    attention: urgent.isNotEmpty,
    notes: [
      'Daily forecast from Open-Meteo for your home area, rounded to about 11 km.',
      'A day counts as wet at a 60% chance of rain, 5 mm or more, or a storm or snow; hot is a high of 36° or more; windy is 40 km/h or more.',
      if (windy.isNotEmpty)
        'Windy: ${windy.map((d) => weekdayShort(d.date)).join(', ')}.',
      'Best-day-outside score weighs rain chance and amount, heat, cold and wind.',
    ],
    signature: fingerprint([
      for (final d in week)
        [d.date, d.code, d.tempMax.round(), d.precipMm.round()],
    ]),
    rawData: weatherRows(i),
    question:
        'From the forecast rows, tell me what the next 7 days from '
        '${dateLine.format(i.today)} look like outside: which days to expect '
        'rain, heat or strong wind, the day best suited to being outdoors, '
        'and anything worth planning around. "headline" is the main thing to '
        'know in a few words; "date" is the day it applies to when there is one.',
  );
}

/// The day to wash the bike: dry and calm on the day, dry for the two days
/// after so rain does not undo it, not scorching (soap dries into spots), and
/// a light calendar.
LifeForecast? forecastBikeWash(LifeInputs i) {
  final w = i.weather;
  if (w == null) return null;
  final hours = eventHoursByDay(i);
  double wetness(WeatherDay d) =>
      (d.precipProbability / 100 + d.precipMm / 10).clamp(0, 2).toDouble();

  final candidates = <({WeatherDay day, double score})>[];
  for (var k = 0; k < 7; k++) {
    final d = w.on(i.today.add(Duration(days: k)));
    if (d == null) continue;
    final next = w.on(d.date.add(const Duration(days: 1)));
    final after = w.on(d.date.add(const Duration(days: 2)));
    var score = -3 * wetness(d);
    if (next != null) score -= 1.5 * wetness(next);
    if (after != null) score -= 0.75 * wetness(after);
    if (d.windMaxKmh > 30) score -= 0.5;
    if (d.tempMax >= 35) score -= 0.5;
    score -= 0.15 * (hours[d.date] ?? 0).clamp(0, 8);
    candidates.add((day: d, score: score));
  }
  if (candidates.length < 3) return null;
  final best = candidates.reduce((a, b) => a.score >= b.score ? a : b);
  final d = best.day;
  final next = w.on(d.date.add(const Duration(days: 1)));
  final after = w.on(d.date.add(const Duration(days: 2)));
  final stays =
      (next == null || !next.isWet) && (after == null || !after.isWet);
  final clean = !d.isWet && stays;

  final when = d.date == i.today
      ? 'today'
      : d.date.difference(i.today).inDays == 1
      ? 'tomorrow'
      : weekdayShort(d.date);
  final upcomingWet = [
    for (final c in candidates)
      if (c.day.isWet) weekdayShort(c.day.date),
  ];
  return LifeForecast(
    kind: LifeForecastKind.bikeWash,
    headline: clean
        ? 'Wash ${when[0].toUpperCase()}${when.substring(1)}'
        : 'Wait, rain around',
    detail: clean
        ? '${d.summary}, ${d.tempMax.round()}° and dry for the next two days, '
              'so the wash will last'
              '${(hours[d.date] ?? 0) == 0 ? '' : '; ${(hours[d.date] ?? 0).toStringAsFixed(1)} hours booked that day'}.'
        : 'No day this week stays dry for two days after. The least bad is '
              '$when (${d.summary.toLowerCase()}, ${d.precipProbability.round()}% '
              'chance of rain); wet days: ${upcomingWet.join(', ')}.',
    date: clean ? d.date : null,
    notes: [
      'Scores the next 7 days: a dry day with light wind, no rain forecast for the next two days, a high under 35° so soap does not dry in spots, and a light calendar.',
      'Daily forecast from Open-Meteo for your home area.',
    ],
    signature: fingerprint([d.date, d.code, d.precipMm.round(), clean]),
    rawData: '${weatherRows(i)}\n\nCalendar:\n${calendarRows(i)}',
    question:
        'Pick the best day in the next 7 days from ${dateLine.format(i.today)} '
        'to wash my motorbike outdoors. It should be dry with light wind, stay '
        'dry for the next two days so the wash lasts, not be extremely hot, '
        'and fall on a day with spare time. If no day qualifies, say to wait. '
        '"headline" is the day; "date" the date.',
  );
}
