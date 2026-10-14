import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/app_log.dart';
import 'package:personal/core/prefs.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/features/location/location_service.dart';
import 'package:personal/features/prompts/personal_info_firestore_service.dart';

const _odometerKey = 'bike_odometer_v1';
const _updatedAtKey = 'bike_odometer_updated_at_v1';

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// One odometer reading, taken on a day.
class OdometerReading {
  const OdometerReading(this.date, this.km);

  factory OdometerReading.fromJson(Map<String, dynamic> j) => OdometerReading(
    _dayOf(DateTime.parse(j['date'] as String)),
    (j['km'] as num).toDouble(),
  );

  final DateTime date;
  final double km;

  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'km': km};
}

/// Motorcycle km per day from the timeline, with running totals so a span can
/// be summed quickly.
class TimelineKm {
  TimelineKm._(this._days, this._cum, this.start, this.through);

  /// [daily] is km per day; [start] and [through] bound what the timeline
  /// export covers, riding or not.
  factory TimelineKm(
    Map<DateTime, double> daily,
    DateTime start,
    DateTime end,
  ) {
    final days = daily.keys.toList()..sort();
    final cum = <double>[];
    var total = 0.0;
    for (final d in days) {
      total += daily[d]!;
      cum.add(total);
    }
    return TimelineKm._(days, cum, start, end);
  }

  final List<DateTime> _days;
  final List<double> _cum;
  final DateTime start;
  final DateTime through;

  /// Km ridden on days up to and including [day].
  double upTo(DateTime day) {
    var lo = 0;
    var hi = _days.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (_days[mid].isAfter(day)) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo == 0 ? 0 : _cum[lo - 1];
  }

  /// Km ridden after [after], up to and including [to].
  double between(DateTime after, DateTime to) => upTo(to) - upTo(after);
}

/// The readings, oldest first, and what they say about how far the bike goes.
///
/// The odometer is the truth for totals. The timeline [gps] is checked against
/// it over each interval between readings: that ratio shows how much riding
/// the timeline misses, and then lets the timeline fill in the days since the
/// last reading, and the shape of the days between readings.
class OdometerLog {
  const OdometerLog(this.readings, {this.gps});

  static const empty = OdometerLog([]);

  final List<OdometerReading> readings;
  final TimelineKm? gps;

  bool get isEmpty => readings.isEmpty;
  OdometerReading? get latest => readings.isEmpty ? null : readings.last;

  /// Two readings are the least that say anything about distance ridden.
  bool get canMeasure => readings.length >= 2;

  bool loggedInMonthOf(DateTime day) =>
      readings.any((r) => r.date.year == day.year && r.date.month == day.month);

  bool _gpsCovers(DateTime from, DateTime to) =>
      gps != null && !gps!.start.isAfter(from) && !gps!.through.isBefore(to);

  /// Intervals the timeline fully covers with enough riding to compare.
  List<({double odometerKm, double timelineKm})> get comparedLegs => [
    for (final l in legs)
      if (l.km > 0 &&
          _gpsCovers(l.from, l.to) &&
          gps!.between(l.from, l.to) >= 10)
        (odometerKm: l.km, timelineKm: gps!.between(l.from, l.to)),
  ];

  /// Odometer km per timeline km (typically above 1: the timeline misses
  /// some trips). Null when no interval can be compared.
  double? get gpsRatio {
    final legs = comparedLegs;
    if (legs.isEmpty) return null;
    final ratios = [for (final l in legs) l.odometerKm / l.timelineKm]..sort();
    final mid = ratios.length ~/ 2;
    final median = ratios.length.isOdd
        ? ratios[mid]
        : (ratios[mid - 1] + ratios[mid]) / 2;
    return median.clamp(0.5, 3.0);
  }

  /// Share of your real km the timeline records, from the compared intervals.
  double? get timelineShare {
    final r = gpsRatio;
    return r == null ? null : (1 / r).clamp(0.0, 1.0);
  }

  /// Km per day lately: the timeline's last weeks scaled by [gpsRatio] when
  /// it is up to date, else the pace over the last few readings.
  double? get dailyRate {
    if (!canMeasure) return null;
    final ratio = gpsRatio;
    final g = gps;
    if (ratio != null && g != null) {
      final from = g.through.subtract(const Duration(days: 56));
      if (!g.start.isAfter(from)) {
        final km = ratio * g.between(from, g.through) / 56;
        if (km > 0) return km;
      }
    }
    final first = readings[readings.length > 3 ? readings.length - 3 : 0];
    final days = readings.last.date.difference(first.date).inDays;
    if (days <= 0) return null;
    final rate = (readings.last.km - first.km) / days;
    return rate < 0 ? 0 : rate;
  }

  /// Km per 30 days, the "per month" figure.
  double? get perMonth => dailyRate == null ? null : dailyRate! * 30.4;

  /// Odometer on [day]. Between readings the timeline's riding days shape the
  /// climb; after the last reading the calibrated timeline carries on, then
  /// the recent rate, up to [today].
  double? kmAt(DateTime day, DateTime today) {
    if (!canMeasure) return null;
    final d = _dayOf(day);
    if (!d.isAfter(readings.first.date)) return readings.first.km;
    for (var i = 1; i < readings.length; i++) {
      final a = readings[i - 1];
      final b = readings[i];
      if (d.isAfter(b.date)) continue;
      final span = b.date.difference(a.date).inDays;
      if (span <= 0) return b.km;
      var share = d.difference(a.date).inDays / span;
      if (_gpsCovers(a.date, b.date)) {
        final total = gps!.between(a.date, b.date);
        if (total > 0) share = gps!.between(a.date, d) / total;
      }
      return a.km + (b.km - a.km) * share;
    }
    final last = readings.last;
    final to = d.isAfter(_dayOf(today)) ? _dayOf(today) : d;
    var km = last.km;
    var from = last.date;
    final ratio = gpsRatio;
    final g = gps;
    if (ratio != null && g != null && !g.start.isAfter(last.date)) {
      final end = to.isBefore(g.through) ? to : g.through;
      if (end.isAfter(from)) {
        km += ratio * g.between(from, end);
        from = end;
      }
    }
    final ahead = to.difference(from).inDays;
    return km + (ahead <= 0 ? 0 : ahead * (dailyRate ?? 0));
  }

  /// Km ridden from [from] up to [to] (capped at [today]); null without data.
  double? kmBetween(DateTime from, DateTime to, DateTime today) {
    final a = kmAt(from, today);
    final b = kmAt(to, today);
    if (a == null || b == null) return null;
    return b - a;
  }

  /// Km between each pair of readings, newest last.
  List<({DateTime from, DateTime to, double km})> get legs => [
    for (var i = 1; i < readings.length; i++)
      (
        from: readings[i - 1].date,
        to: readings[i].date,
        km: readings[i].km - readings[i - 1].km,
      ),
  ];

  /// One line for the AI: recent readings, the rate and timeline coverage.
  String promptLine() {
    if (readings.isEmpty) return '';
    final f = DateFormat('yyyy-MM-dd');
    final recent = readings.length > 6
        ? readings.sublist(readings.length - 6)
        : readings;
    final rate = perMonth;
    final share = timelineShare;
    return 'Bike odometer readings: '
        '${recent.map((r) => '${f.format(r.date)} ${r.km.round()} km').join('; ')}'
        '${rate == null ? '' : ' (about ${rate.round()} km a month)'}'
        '${share == null ? '' : '; the location timeline records about ${(share * 100).round()}% of the real km'}.';
  }
}

/// Odometer readings kept on the device, so they survive launches.
final odometerProvider =
    NotifierProvider<OdometerNotifier, List<OdometerReading>>(
      OdometerNotifier.new,
    );

final odometerLogProvider = Provider<OdometerLog>((ref) {
  final readings = _withFuelReadings(
    ref.watch(odometerProvider),
    ref.watch(expensesSummaryProvider),
  );
  final activities = ref.watch(locationSummaryProvider).activities;
  if (activities.isEmpty) return OdometerLog(readings);
  final daily = <DateTime, double>{};
  var start = _dayOf(activities.first.startTime);
  var end = _dayOf(activities.first.endTime);
  for (final a in activities) {
    final s = _dayOf(a.startTime);
    final e = _dayOf(a.endTime);
    if (s.isBefore(start)) start = s;
    if (e.isAfter(end)) end = e;
    if (a.isMotorcycling && a.distanceMeters > 0) {
      daily[s] = (daily[s] ?? 0) + a.distanceMeters / 1000;
    }
  }
  return OdometerLog(readings, gps: TimelineKm(daily, start, end));
});

/// Adds readings noted in fuel entries' descriptions. A logged reading wins
/// on the same day, and a fuel reading that would make the odometer run
/// backwards is ignored as a typo.
List<OdometerReading> _withFuelReadings(
  List<OdometerReading> logged,
  ExpensesSummary expenses,
) {
  final byDay = <DateTime, OdometerReading>{for (final r in logged) r.date: r};
  final fromFuel = <DateTime, double>{};
  for (final t in expenses.transactions) {
    if (!t.isRealExpense || !ExpensesSummary.isFuelExpense(t)) continue;
    final km = ExpensesSummary.odometerKmFromDescription(t);
    if (km == null) continue;
    final day = _dayOf(t.date);
    if (byDay.containsKey(day)) continue;
    final prev = fromFuel[day];
    if (prev == null || km > prev) fromFuel[day] = km;
  }
  if (fromFuel.isEmpty) return logged;
  final all = [
    ...logged,
    for (final e in fromFuel.entries) OdometerReading(e.key, e.value),
  ]..sort((a, b) => a.date.compareTo(b.date));
  final loggedDays = {for (final r in logged) r.date};
  final out = <OdometerReading>[];
  for (final r in all) {
    final isLogged = loggedDays.contains(r.date);
    if (!isLogged && out.isNotEmpty && r.km < out.last.km) continue;
    out.add(r);
  }
  return out;
}

class OdometerNotifier extends Notifier<List<OdometerReading>> {
  static List<OdometerReading> _memoryFallback = const [];

  bool _changed = false;

  @override
  List<OdometerReading> build() {
    unawaited(_hydrate().then((_) => syncFromCloud()));
    return _memoryFallback;
  }

  Future<void> _hydrate() async {
    final prefs = await safePrefs();
    if (prefs == null || _changed) return;
    final raw = prefs.getString(_odometerKey);
    if (raw == null || _changed) return;
    try {
      final loaded = [
        for (final j in jsonDecode(raw) as List)
          OdometerReading.fromJson(j as Map<String, dynamic>),
      ]..sort((a, b) => a.date.compareTo(b.date));
      _memoryFallback = loaded;
      state = loaded;
    } catch (_) {
      // An unreadable store is treated as no readings.
    }
  }

  /// Pulls the readings saved with the personal information when they are
  /// newer than these, or pushes these when they are newer (or not saved yet).
  Future<void> syncFromCloud() async {
    final user = ref.read(googleAccountServiceProvider).currentUser;
    if (user == null) return;
    try {
      final firestore = ref.read(personalInfoFirestoreServiceProvider);
      final cloud = await firestore.loadOdometer(user.uid);
      final prefs = await safePrefs();
      final localMillis = prefs?.getInt(_updatedAtKey);
      final cloudAt = cloud?.updatedAt;
      final cloudNewer =
          cloud != null &&
          cloudAt != null &&
          (localMillis == null || cloudAt.millisecondsSinceEpoch > localMillis);
      if (cloudNewer) {
        await _save(cloud.readings, push: false, at: cloudAt);
      } else if (state.isNotEmpty && (cloud == null || localMillis != null)) {
        await _push();
      }
    } catch (error) {
      AppLog.warn('Could not sync odometer with the cloud: $error');
    }
  }

  Future<void> _push() async {
    final user = ref.read(googleAccountServiceProvider).currentUser;
    if (user == null) return;
    try {
      final at = await ref
          .read(personalInfoFirestoreServiceProvider)
          .saveOdometer(user.uid, state);
      if (at != null) {
        await (await safePrefs())?.setInt(
          _updatedAtKey,
          at.millisecondsSinceEpoch,
        );
      }
    } catch (error) {
      AppLog.warn('Could not save odometer to the cloud: $error');
    }
  }

  Future<void> _save(
    List<OdometerReading> next, {
    bool push = true,
    DateTime? at,
  }) async {
    _changed = true;
    _memoryFallback = next;
    state = next;
    final prefs = await safePrefs();
    await prefs?.setString(
      _odometerKey,
      jsonEncode([for (final r in next) r.toJson()]),
    );
    await prefs?.setInt(
      _updatedAtKey,
      (at ?? DateTime.now()).millisecondsSinceEpoch,
    );
    if (push) await _push();
  }

  /// Adds a reading, replacing one on the same day. Returns why it was
  /// refused, or null when saved. An odometer never runs backwards.
  Future<String?> add(DateTime date, double km) async {
    final day = _dayOf(date);
    if (km <= 0) return 'Enter the number on the odometer.';
    if (day.isAfter(_dayOf(DateTime.now()))) {
      return 'That date is in the future.';
    }
    final others = [
      for (final r in state)
        if (r.date != day) r,
    ];
    for (final r in others) {
      if (r.date.isBefore(day) && r.km > km) {
        return 'Lower than the ${r.km.round()} km logged earlier.';
      }
      if (r.date.isAfter(day) && r.km < km) {
        return 'Higher than the ${r.km.round()} km logged later.';
      }
    }
    await _save(
      [...others, OdometerReading(day, km)]
        ..sort((a, b) => a.date.compareTo(b.date)),
    );
    return null;
  }

  Future<void> remove(OdometerReading reading) => _save([
    for (final r in state)
      if (r.date != reading.date) r,
  ]);
}
