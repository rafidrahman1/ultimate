import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/timeline_profile.dart';

enum PlaceKind { home, work, other }

/// Visits closer than this to the profile's home/work point count as it, even
/// when Google didn't label the visit.
const _labelMatchMeters = 150.0;

/// Time at a place shorter than this isn't a real stop (traffic lights, GPS
/// jitter), so it doesn't count toward "places visited".
const _minStop = Duration(minutes: 10);

/// Departing or arriving more than this apart isn't one commute.
const _maxCommute = Duration(hours: 3);

class PlaceStat {
  const PlaceStat({
    required this.placeId,
    required this.kind,
    required this.visits,
    required this.totalDwell,
    required this.firstSeen,
    required this.lastSeen,
    this.point,
  });

  final String placeId;
  final PlaceKind kind;
  final GeoPoint? point;
  final int visits;
  final Duration totalDwell;
  final DateTime firstSeen;
  final DateTime lastSeen;

  Duration get averageStay =>
      visits == 0 ? Duration.zero : totalDwell ~/ visits;
}

/// Where the tracked time went.
class TimeSplit {
  const TimeSplit({
    required this.home,
    required this.work,
    required this.elsewhere,
    required this.days,
  });

  static const empty = TimeSplit(
    home: Duration.zero,
    work: Duration.zero,
    elsewhere: Duration.zero,
    days: 0,
  );

  final Duration home;
  final Duration work;
  final Duration elsewhere;

  /// Days with any recorded time.
  final int days;

  Duration get total => home + work + elsewhere;
  bool get hasData => days > 0 && total > Duration.zero;

  double _perDay(Duration d) => days == 0 ? 0 : d.inMinutes / 60 / days;
  double get homeHoursPerDay => _perDay(home);
  double get workHoursPerDay => _perDay(work);
  double get elsewhereHoursPerDay => _perDay(elsewhere);

  double _share(Duration d) =>
      total == Duration.zero ? 0 : d.inMinutes / total.inMinutes;
  double get homeShare => _share(home);
  double get workShare => _share(work);
  double get elsewhereShare => _share(elsewhere);
}

/// One day's time at each kind of place.
class DayTime {
  const DayTime(this.date, this.home, this.work, this.elsewhere);

  final DateTime date;
  final Duration home;
  final Duration work;
  final Duration elsewhere;

  Duration get tracked => home + work + elsewhere;

  /// Everything that wasn't spent at home.
  Duration get away => work + elsewhere;
}

class CommuteSample {
  const CommuteSample({required this.departed, required this.arrived});

  final DateTime departed;
  final DateTime arrived;

  Duration get duration => arrived.difference(departed);
}

/// Door-to-door commutes, measured from when a home/work visit ended to when
/// the next one began. Nearer to what you experience than a single ride.
class CommuteStats {
  const CommuteStats({this.toWork = const [], this.toHome = const []});

  static const empty = CommuteStats();

  final List<CommuteSample> toWork;
  final List<CommuteSample> toHome;

  bool get hasData => toWork.isNotEmpty || toHome.isNotEmpty;

  static Duration? averageDuration(List<CommuteSample> samples) {
    if (samples.isEmpty) return null;
    final total = samples.fold<int>(0, (sum, s) => sum + s.duration.inSeconds);
    return Duration(seconds: total ~/ samples.length);
  }

  /// Mean time of day as minutes after midnight.
  static int? averageDepartureMinutes(List<CommuteSample> samples) {
    if (samples.isEmpty) return null;
    final total = samples.fold<int>(
      0,
      (sum, s) => sum + s.departed.hour * 60 + s.departed.minute,
    );
    return total ~/ samples.length;
  }
}

class LocationInsights {
  const LocationInsights({
    this.places = const [],
    this.split = TimeSplit.empty,
    this.daily = const [],
    this.commute = CommuteStats.empty,
    this.uniquePlaces = 0,
    this.newPlaces,
    this.furthestFromHomeKm,
    this.furthestOn,
  });

  static const empty = LocationInsights();

  /// Places visited in the period, most time first.
  final List<PlaceStat> places;
  final TimeSplit split;

  /// Per-day time split, oldest first, only for days with recorded time.
  final List<DayTime> daily;
  final CommuteStats commute;

  /// Places with at least one real stop in the period.
  final int uniquePlaces;

  /// Places whose first-ever visit falls in the period, or null when there is
  /// no earlier history to compare against.
  final int? newPlaces;
  final double? furthestFromHomeKm;
  final DateTime? furthestOn;

  bool get hasData => places.isNotEmpty;
}

/// Works out what kind of place each id is: the majority of Google's own
/// labels across visits, falling back to proximity to the profile's home/work.
Map<String, PlaceKind> classifyPlaces(LocationSummary summary) {
  final votes = <String, List<int>>{}; // id -> [home, work, other]
  for (final visit in summary.placeVisits) {
    final id = visit.placeId;
    if (id == null || visit.isNested) continue;
    final tally = votes.putIfAbsent(id, () => [0, 0, 0]);
    if (visit.isAtHome) {
      tally[0]++;
    } else if (visit.isAtWork) {
      tally[1]++;
    } else {
      tally[2]++;
    }
  }

  final home = summary.profile.home;
  final work = summary.profile.work;
  final points = <String, GeoPoint>{};
  for (final visit in summary.placeVisits) {
    final id = visit.placeId;
    final point = visit.point;
    if (id != null && point != null) points.putIfAbsent(id, () => point);
  }

  final kinds = <String, PlaceKind>{};
  votes.forEach((id, tally) {
    final labelled = tally[0] + tally[1];
    if (labelled > 0 && labelled >= tally[2] ~/ 2) {
      kinds[id] = tally[0] >= tally[1] ? PlaceKind.home : PlaceKind.work;
      return;
    }
    final point = points[id];
    if (point != null) {
      if (home != null && point.distanceTo(home) <= _labelMatchMeters) {
        kinds[id] = PlaceKind.home;
        return;
      }
      if (work != null && point.distanceTo(work) <= _labelMatchMeters) {
        kinds[id] = PlaceKind.work;
        return;
      }
    }
    kinds[id] = PlaceKind.other;
  });
  return kinds;
}

/// Insights for visits starting in `[start, end]`. Pass the *whole* summary:
/// "new places" needs the history before [start].
LocationInsights computeLocationInsights(
  LocationSummary summary,
  DateTime start,
  DateTime end,
) {
  final visits = summary.placeVisits.where((v) => !v.isNested).toList();
  if (visits.isEmpty) return LocationInsights.empty;

  final kinds = classifyPlaces(summary);
  PlaceKind kindOf(TimelinePlaceVisit v) {
    final id = v.placeId;
    if (id != null && kinds[id] != null) return kinds[id]!;
    if (v.isAtHome) return PlaceKind.home;
    if (v.isAtWork) return PlaceKind.work;
    return PlaceKind.other;
  }

  // First time each place was ever seen, across the whole export.
  final firstEver = <String, DateTime>{};
  DateTime? earliest;
  for (final v in visits) {
    final local = v.startTime.toLocal();
    if (earliest == null || local.isBefore(earliest)) earliest = local;
    final id = v.placeId;
    if (id == null) continue;
    final seen = firstEver[id];
    if (seen == null || local.isBefore(seen)) firstEver[id] = local;
  }

  final inPeriod = visits.where((v) {
    final local = v.startTime.toLocal();
    return !local.isBefore(start) && !local.isAfter(end);
  }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  if (inPeriod.isEmpty) return LocationInsights.empty;

  final perDay = <DateTime, List<Duration>>{}; // [home, work, other]
  final byPlace = <String, _Acc>{};
  final home0 = summary.profile.home;
  double? furthest;
  DateTime? furthestOn;

  for (final v in inPeriod) {
    final from = v.startTime.toLocal();
    final to = v.endTime.toLocal();
    final kind = kindOf(v);

    // Slice the stay at midnight so a multi-day stay counts on every day.
    var cursor = from.isBefore(start) ? start : from;
    final stop = to.isAfter(end) ? end : to;
    var dwell = Duration.zero;
    while (cursor.isBefore(stop)) {
      final dayStart = DateTime(cursor.year, cursor.month, cursor.day);
      final nextDay = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final sliceEnd = stop.isBefore(nextDay) ? stop : nextDay;
      final slice = sliceEnd.difference(cursor);
      final bucket = perDay.putIfAbsent(
        dayStart,
        () => [Duration.zero, Duration.zero, Duration.zero],
      );
      final i = switch (kind) {
        PlaceKind.home => 0,
        PlaceKind.work => 1,
        PlaceKind.other => 2,
      };
      bucket[i] += slice;
      dwell += slice;
      cursor = sliceEnd;
    }

    final id = v.placeId;
    if (id != null) {
      final acc = byPlace.putIfAbsent(id, () => _Acc(kind, v.point, from));
      acc.visits++;
      acc.dwell += dwell;
      if (from.isBefore(acc.first)) acc.first = from;
      if (to.isAfter(acc.last)) acc.last = to;
    }

    final point = v.point;
    if (home0 != null && point != null && dwell >= _minStop) {
      final km = point.distanceTo(home0) / 1000;
      if (furthest == null || km > furthest) {
        furthest = km;
        furthestOn = from;
      }
    }
  }

  final daily = [
    for (final entry
        in perDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
      DayTime(entry.key, entry.value[0], entry.value[1], entry.value[2]),
  ];
  final home = daily.fold(Duration.zero, (sum, d) => sum + d.home);
  final work = daily.fold(Duration.zero, (sum, d) => sum + d.work);
  final elsewhere = daily.fold(Duration.zero, (sum, d) => sum + d.elsewhere);

  final places =
      [
        for (final entry in byPlace.entries)
          PlaceStat(
            placeId: entry.key,
            kind: entry.value.kind,
            point: entry.value.point,
            visits: entry.value.visits,
            totalDwell: entry.value.dwell,
            firstSeen: entry.value.first,
            lastSeen: entry.value.last,
          ),
      ]..sort((a, b) {
        final byTime = b.totalDwell.compareTo(a.totalDwell);
        return byTime != 0 ? byTime : b.visits.compareTo(a.visits);
      });

  final real = places.where((p) => p.totalDwell >= _minStop).toList();
  final hasHistory =
      earliest != null &&
      earliest.isBefore(start.subtract(const Duration(days: 7)));
  final fresh = hasHistory
      ? real.where((p) {
          final first = firstEver[p.placeId];
          return first != null && !first.isBefore(start);
        }).length
      : null;

  return LocationInsights(
    places: places,
    split: TimeSplit(
      home: home,
      work: work,
      elsewhere: elsewhere,
      days: daily.length,
    ),
    daily: daily,
    commute: _commutes(inPeriod, kindOf),
    uniquePlaces: real.length,
    newPlaces: fresh,
    furthestFromHomeKm: furthest,
    furthestOn: furthestOn,
  );
}

class _Acc {
  _Acc(this.kind, this.point, this.first) : last = first;

  final PlaceKind kind;
  final GeoPoint? point;
  int visits = 0;
  Duration dwell = Duration.zero;
  DateTime first;
  DateTime last;
}

/// Pairs each home visit's end with the next work visit's start (and the
/// reverse) when they fall within [_maxCommute] of each other.
CommuteStats _commutes(
  List<TimelinePlaceVisit> sorted,
  PlaceKind Function(TimelinePlaceVisit) kindOf,
) {
  final toWork = <CommuteSample>[];
  final toHome = <CommuteSample>[];
  final seenWorkDays = <String>{};
  final seenHomeDays = <String>{};

  for (var i = 0; i + 1 < sorted.length; i++) {
    final a = sorted[i];
    final b = sorted[i + 1];
    final left = a.endTime.toLocal();
    final arrived = b.startTime.toLocal();
    final gap = arrived.difference(left);
    if (gap <= Duration.zero || gap > _maxCommute) continue;

    final from = kindOf(a);
    final to = kindOf(b);
    final day = '${arrived.year}-${arrived.month}-${arrived.day}';
    if (from == PlaceKind.home && to == PlaceKind.work) {
      // First home→work of the day only; later hops are errands.
      if (seenWorkDays.add(day)) {
        toWork.add(CommuteSample(departed: left, arrived: arrived));
      }
    } else if (from == PlaceKind.work && to == PlaceKind.home) {
      if (seenHomeDays.add(day)) {
        toHome.add(CommuteSample(departed: left, arrived: arrived));
      }
    }
  }
  return CommuteStats(toWork: toWork, toHome: toHome);
}

/// One calendar month of travel, for trend charts.
class MonthlyLocationRow {
  const MonthlyLocationRow({
    required this.month,
    required this.motorcycleKm,
    required this.totalKm,
    required this.rides,
    required this.workDays,
  });

  final DateTime month;
  final double motorcycleKm;
  final double totalKm;
  final int rides;
  final int workDays;
}

/// Every month from the first to the last segment, oldest first, including
/// months with no data (as zeros) so a chart's x-axis stays continuous.
List<MonthlyLocationRow> buildMonthlyHistory(LocationSummary summary) {
  final motoKm = <int, double>{};
  final totalKm = <int, double>{};
  final rides = <int, int>{};
  final workDays = <int, Set<int>>{};

  int key(DateTime d) => d.year * 12 + (d.month - 1);

  for (final a in summary.activities) {
    final local = a.startTime.toLocal();
    final k = key(local);
    totalKm[k] = (totalKm[k] ?? 0) + a.distanceMeters / 1000;
    if (a.isMotorcycling) {
      motoKm[k] = (motoKm[k] ?? 0) + a.distanceMeters / 1000;
      rides[k] = (rides[k] ?? 0) + 1;
    }
  }
  for (final v in summary.placeVisits) {
    if (v.isNested || !(v.isWork)) continue;
    final local = v.startTime.toLocal();
    workDays.putIfAbsent(key(local), () => {}).add(local.day);
  }

  final keys = {...totalKm.keys, ...workDays.keys};
  if (keys.isEmpty) return const [];
  final first = keys.reduce((a, b) => a < b ? a : b);
  final last = keys.reduce((a, b) => a > b ? a : b);

  return [
    for (var k = first; k <= last; k++)
      MonthlyLocationRow(
        month: DateTime(k ~/ 12, k % 12 + 1),
        motorcycleKm: motoKm[k] ?? 0,
        totalKm: totalKm[k] ?? 0,
        rides: rides[k] ?? 0,
        workDays: workDays[k]?.length ?? 0,
      ),
  ];
}
