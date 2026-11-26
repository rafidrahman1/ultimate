import 'package:personal/features/calendar/data/day_off.dart';
import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/forecasts/life/life_forecasts_commute.dart';
import 'package:personal/features/forecasts/life/life_raw_data.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_profile.dart';
import 'package:personal/features/weather/data/weather_models.dart';

/// How long the trip to work takes on one kind of day, from your timeline.
class CommuteTripStats {
  const CommuteTripStats({
    required this.typical,
    required this.safe,
    required this.target,
    required this.trips,
  });

  factory CommuteTripStats.fromJson(Map<String, dynamic> json) =>
      CommuteTripStats(
        typical: (json['typical'] as num).toDouble(),
        safe: (json['safe'] as num).toDouble(),
        target: json['target'] as int,
        trips: json['trips'] as int? ?? 0,
      );

  /// Median door-to-door minutes.
  final double typical;

  /// Minutes that covered 8 in 10 of those trips.
  final double safe;

  /// When to be at work, as minutes after midnight.
  final int target;

  /// How many trips these come from.
  final int trips;

  Map<String, dynamic> toJson() => {
    'typical': typical,
    'safe': safe,
    'target': target,
    'trips': trips,
  };
}

/// One past trip to work: the day, and when you left home and reached work
/// (minutes after midnight).
typedef CommuteTrip = ({DateTime day, int left, int arrived});

/// The weather forecast for one day, as the reminder needs it.
typedef CommuteWeather = ({bool wet, String note});

CommuteWeather _weatherFromJson(Map<String, dynamic> json) =>
    (wet: json['wet'] as bool? ?? false, note: json['note'] as String? ?? '');

/// Everything the leave-for-work reminder needs, worked out from the
/// timeline while the app is open and saved, so the reminder can run later
/// in the background without loading the timeline.
class CommuteProfile {
  const CommuteProfile({
    required this.home,
    required this.work,
    required this.overall,
    required this.byWeekday,
    required this.commuteWeekdays,
    required this.weekendDays,
    required this.holidays,
    this.calibration,
    this.calibrationTrips = 0,
    this.recentTrips = const [],
    this.weather = const {},
  });

  factory CommuteProfile.fromJson(Map<String, dynamic> json) {
    GeoPoint point(Object? raw) {
      final list = (raw as List).cast<num>();
      return GeoPoint(list[0].toDouble(), list[1].toDouble());
    }

    return CommuteProfile(
      home: point(json['home']),
      work: point(json['work']),
      overall: CommuteTripStats.fromJson(
        (json['overall'] as Map).cast<String, dynamic>(),
      ),
      byWeekday: {
        for (final e in (json['byWeekday'] as Map).entries)
          int.parse(e.key as String): CommuteTripStats.fromJson(
            (e.value as Map).cast<String, dynamic>(),
          ),
      },
      commuteWeekdays: (json['commuteWeekdays'] as List).cast<int>().toSet(),
      weekendDays: (json['weekendDays'] as List).cast<int>(),
      holidays: {
        for (final d in (json['holidays'] as List).cast<String>())
          DateTime.parse(d),
      },
      calibration: (json['calibration'] as num?)?.toDouble(),
      calibrationTrips: json['calibrationTrips'] as int? ?? 0,
      recentTrips: [
        for (final t in (json['recentTrips'] as List? ?? const []))
          (
            day: DateTime.parse((t as Map)['day'] as String),
            left: t['left'] as int,
            arrived: t['arrived'] as int,
          ),
      ],
      weather: {
        for (final e in ((json['weather'] as Map?) ?? const {}).entries)
          DateTime.parse(e.key as String): _weatherFromJson(
            (e.value as Map).cast<String, dynamic>(),
          ),
      },
    );
  }

  final GeoPoint home;
  final GeoPoint work;
  final CommuteTripStats overall;

  /// Per weekday (DateTime.monday..sunday) when there are enough trips.
  final Map<int, CommuteTripStats> byWeekday;

  /// Weekdays you usually go to work.
  final Set<int> commuteWeekdays;
  final List<int> weekendDays;
  final Set<DateTime> holidays;

  /// Your real trip time divided by Google's traffic estimate, from days
  /// where both are known; null until there are enough of them.
  final double? calibration;
  final int calibrationTrips;

  /// The last 8 weeks of trips, oldest first.
  final List<CommuteTrip> recentTrips;

  /// Forecast for the coming days, keyed by local midnight.
  final Map<DateTime, CommuteWeather> weather;

  CommuteWeather? weatherOn(DateTime day) =>
      weather[DateTime(day.year, day.month, day.day)];

  CommuteTripStats statsFor(DateTime day) => byWeekday[day.weekday] ?? overall;

  bool isCommuteDay(DateTime day) =>
      commuteWeekdays.contains(day.weekday) &&
      !isDayOffOn(day, weekendDays: weekendDays, holidays: holidays);

  Map<String, dynamic> toJson() => {
    'home': [home.latitude, home.longitude],
    'work': [work.latitude, work.longitude],
    'overall': overall.toJson(),
    'byWeekday': {
      for (final e in byWeekday.entries) '${e.key}': e.value.toJson(),
    },
    'commuteWeekdays': commuteWeekdays.toList()..sort(),
    'weekendDays': weekendDays,
    'holidays': [
      for (final d in holidays)
        DateTime(d.year, d.month, d.day).toIso8601String(),
    ],
    if (calibration != null) 'calibration': calibration,
    'calibrationTrips': calibrationTrips,
    'recentTrips': [
      for (final t in recentTrips)
        {'day': t.day.toIso8601String(), 'left': t.left, 'arrived': t.arrived},
    ],
    'weather': {
      for (final e in weather.entries)
        e.key.toIso8601String(): {'wet': e.value.wet, 'note': e.value.note},
    },
  };
}

/// Fewest day pairs (Google estimate and your actual trip) before Google's
/// figure is corrected to your own trips.
const commuteCalibrationMinTrips = 3;

/// Builds the profile from the last 8 weeks of the timeline; null when there
/// are too few home-to-work trips or home/work have no coordinates.
///
/// [googleMinutes] is Google's traffic estimate the reminder got on each day,
/// compared with the trip you actually made that day to learn how your
/// door-to-door time relates to Google's.
CommuteProfile? buildCommuteProfile(
  LifeInputs i, {
  Map<DateTime, int> googleMinutes = const {},
}) {
  final cutoff = i.today.subtract(const Duration(days: 56));
  final samples = [
    for (final s in commuteSamples(i))
      if (!s.day.isBefore(cutoff)) s,
  ];
  if (samples.length < 5) return null;

  final home = _medianPoint(i, cutoff, (v) => v.isAtHome);
  final work = _medianPoint(i, cutoff, (v) => v.isAtWork);
  if (home == null || work == null) return null;

  int minutes(CommuteSample s) => s.arrived.difference(s.left).inMinutes;
  final scheduled = i.work.scheduledArrivalTime;

  CommuteTripStats stats(List<CommuteSample> pool) {
    final durations = [for (final s in pool) minutes(s).toDouble()];
    return CommuteTripStats(
      typical: median(durations),
      safe: quantile(durations, 0.8),
      target: scheduled != null
          ? scheduled.hour * 60 + scheduled.minute
          : median([
              for (final s in pool) minutesOfDay(s.arrived).toDouble(),
            ]).round(),
      trips: pool.length,
    );
  }

  final counts = <int, int>{};
  for (final s in samples) {
    counts.update(s.day.weekday, (n) => n + 1, ifAbsent: () => 1);
  }
  final byWeekday = <int, CommuteTripStats>{
    for (final e in counts.entries)
      if (e.value >= 3)
        e.key: stats([
          for (final s in samples)
            if (s.day.weekday == e.key) s,
        ]),
  };

  final ratios = <double>[];
  for (final s in commuteSamples(i)) {
    final google = googleMinutes[s.day];
    if (google == null || google <= 0) continue;
    ratios.add(minutes(s) / google);
  }
  final calibrated = ratios.length >= commuteCalibrationMinTrips;

  return CommuteProfile(
    home: home,
    work: work,
    overall: stats(samples),
    byWeekday: byWeekday,
    commuteWeekdays: {
      for (final e in counts.entries)
        if (e.value >= 2) e.key,
    },
    weekendDays: i.weekendDays,
    holidays: {
      for (final d in holidayDays(i))
        if (!d.isBefore(i.today)) d,
    },
    calibration: calibrated ? median(ratios).clamp(0.5, 2.0).toDouble() : null,
    calibrationTrips: ratios.length,
    recentTrips: [
      for (final s in samples)
        (
          day: DateTime(s.day.year, s.day.month, s.day.day),
          left: minutesOfDay(s.left),
          arrived: minutesOfDay(s.arrived),
        ),
    ],
    weather: {
      for (final d in i.weather?.days ?? const <WeatherDay>[])
        if (!d.date.isBefore(i.today))
          DateTime(d.date.year, d.date.month, d.date.day): (
            wet: d.isWet,
            note:
                '${d.summary}, rain ${d.precipProbability.round()}% '
                '(${d.precipMm.toStringAsFixed(1)} mm), '
                'wind ${d.windMaxKmh.round()} km/h',
          ),
    },
  );
}

/// The median coordinates of recent visits matching [test].
GeoPoint? _medianPoint(
  LifeInputs i,
  DateTime since,
  bool Function(TimelinePlaceVisit visit) test,
) {
  final points = [
    for (final v in i.placeVisits)
      if (!v.isNested &&
          test(v) &&
          v.point != null &&
          !v.endTime.isBefore(since))
        v.point!,
  ];
  if (points.isEmpty) {
    points.addAll([
      for (final v in i.placeVisits)
        if (!v.isNested && test(v) && v.point != null) v.point!,
    ]);
  }
  if (points.isEmpty) return null;
  return GeoPoint(
    median([for (final p in points) p.latitude]),
    median([for (final p in points) p.longitude]),
  );
}
