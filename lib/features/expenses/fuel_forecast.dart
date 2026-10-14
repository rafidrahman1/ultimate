import 'package:personal/core/day_off.dart';
import 'package:personal/features/bike/odometer_service.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/location/timeline_activity.dart';

/// What riding distance says about the tank. Present only when the location
/// export overlaps enough past refuels to learn how far a refill lasts.
class FuelDistanceModel {
  const FuelDistanceModel({
    required this.kmSinceLastRefuel,
    required this.tankRangeKm,
    required this.kmLeft,
    required this.kmPerCurrency,
    required this.dailyKm,
    required this.gapsUsed,
    required this.locationThrough,
    this.kmPerLitre,
    this.fromOdometer = false,
  });

  /// Motorcycle km ridden since the last refuel, as far as the location
  /// export reaches.
  final double kmSinceLastRefuel;

  /// Km a typical refill has lasted.
  final double tankRangeKm;

  /// Estimated km before the next refill; 0 when already past the usual range.
  final double kmLeft;

  /// Km per unit of currency spent on fuel at the latest price.
  final double kmPerCurrency;

  /// Km per litre, when refuel notes gave enough prices to know litres. The
  /// range is then learned in litres, so a price change doesn't skew it.
  final double? kmPerLitre;

  /// Average km per day over the last weeks.
  final double dailyKm;

  /// Refuel gaps with riding data that the range is learned from.
  final int gapsUsed;

  /// Last day the location export covers.
  final DateTime locationThrough;

  /// Km come from odometer readings rather than recorded rides.
  final bool fromOdometer;
}

/// A guess at when the next fuel purchase will happen and what it will cost.
/// Uses riding distance when location data allows, else the gaps between
/// past refuels.
class FuelForecast {
  const FuelForecast({
    required this.lastRefuel,
    required this.lastAmount,
    required this.typicalIntervalDays,
    required this.typicalAmount,
    required this.expectedDate,
    required this.earliestDate,
    required this.latestDate,
    required this.refuelCount,
    required this.currency,
    required this.dateBasedExpectedDate,
    this.distance,
    this.kmSinceRefuel,
    this.typicalLitres,
    this.lastRatePerLitre,
    this.lastRateDate,
  });

  final DateTime lastRefuel;
  final double lastAmount;

  /// Median days between refuels.
  final double typicalIntervalDays;

  /// What the next refuel should cost: usual litres at the latest price per
  /// litre when both are known, else the median past amount.
  final double typicalAmount;

  /// Median litres per refuel, from refuels whose note carried a price.
  final double? typicalLitres;

  /// Most recent price per litre found in a refuel note.
  final double? lastRatePerLitre;
  final DateTime? lastRateDate;
  final DateTime expectedDate;

  /// Range of plausible dates.
  final DateTime earliestDate;
  final DateTime latestDate;

  /// Refuels the forecast is based on.
  final int refuelCount;
  final String currency;

  /// The estimate from refuel dates alone, kept for comparison.
  final DateTime dateBasedExpectedDate;

  /// Set when [expectedDate] comes from riding distance.
  final FuelDistanceModel? distance;

  /// Km ridden since the last refuel, from the odometer or the location
  /// timeline. Known even when there is too little history for [distance].
  final double? kmSinceRefuel;

  bool get usesDistance => distance != null;

  /// Whole days from [now] to [expectedDate]; negative once overdue.
  int daysUntil(DateTime now) =>
      _day(expectedDate).difference(_day(now)).inDays;

  bool isOverdue(DateTime now) => daysUntil(now) < 0;

  /// Few refuels, or a wide range of dates, make the date a rough guess.
  bool get isRoughGuess => distance != null
      ? distance!.gapsUsed < 3
      : refuelCount < 5 ||
            latestDate.difference(earliestDate).inDays > typicalIntervalDays;

  /// Identifies the data a forecast was built from, so a stored AI estimate
  /// is dropped once a new refuel arrives.
  String get signature =>
      '${lastRefuel.toIso8601String()}|$refuelCount|${lastAmount.round()}';

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// Needs at least [minRefuels] refuels (so two gaps). Refuels on the same day
/// count once, and only the most recent [window] gaps are used so the guess
/// follows current habits. Returns null when there is too little history.
///
/// With [activities] (the location export) the date comes from distance:
/// how far past refills lasted, how far has been ridden since, and the usual
/// riding pace for each weekday. Without enough overlap it falls back to
/// refuel dates alone.
FuelForecast? forecastNextFuelPurchase(
  Iterable<CashewTransaction> transactions, {
  Iterable<TimelineActivity> activities = const [],
  OdometerLog odometer = OdometerLog.empty,
  List<int> weekendDays = const [],
  Set<DateTime> holidays = const {},
  Iterable<TimelinePlaceVisit> placeVisits = const [],
  Map<String, String> placeNames = const {},
  DateTime? now,
  int minRefuels = 3,
  int window = 6,
}) {
  final today = _dayOf(now ?? DateTime.now());
  final byDay = <DateTime, double>{};
  final stampByDay = <DateTime, DateTime>{};
  // Litres for a day, dropped if any refuel that day had no price.
  final litresByDay = <DateTime, double>{};
  final unpricedDays = <DateTime>{};
  double? lastRate;
  DateTime? lastRateDate;
  var currency = '';
  for (final t in transactions) {
    if (!t.isRealExpense || !ExpensesSummary.isFuelExpense(t)) continue;
    final day = _dayOf(t.date);
    final amount = t.amount.abs();
    byDay[day] = (byDay[day] ?? 0) + amount;
    final stamp = t.date.toLocal();
    final seen = stampByDay[day];
    if (seen == null || stamp.isAfter(seen)) stampByDay[day] = stamp;
    if (currency.isEmpty) currency = t.currency;
    final rate = ExpensesSummary.fuelRatePerLitreFromDescription(t);
    if (rate == null) {
      unpricedDays.add(day);
    } else {
      litresByDay[day] = (litresByDay[day] ?? 0) + amount / rate;
      if (lastRateDate == null || !day.isBefore(lastRateDate)) {
        lastRate = rate;
        lastRateDate = day;
      }
    }
  }
  litresByDay.removeWhere((day, _) => unpricedDays.contains(day));
  if (byDay.length < minRefuels) return null;

  final days = byDay.keys.toList()..sort();
  final gaps = [
    for (var i = 1; i < days.length; i++)
      days[i].difference(days[i - 1]).inDays.toDouble(),
  ];
  final recentGaps = gaps.length > window
      ? gaps.sublist(gaps.length - window)
      : gaps;
  final recentAmounts = days
      .map((d) => byDay[d]!)
      .toList()
      .reversed
      .take(window)
      .toList();

  final recentLitres = [
    for (final d in days.reversed.take(window))
      if (litresByDay[d] != null) litresByDay[d]!,
  ];
  final typicalLitres = recentLitres.length >= 2
      ? _quantile(recentLitres, 0.5)
      : null;

  final interval = _quantile(recentGaps, 0.5);
  final pastAmount = _quantile(recentAmounts, 0.5);
  final typicalAmount = typicalLitres != null && lastRate != null
      ? typicalLitres * lastRate
      : pastAmount;
  final last = days.last;
  DateTime after(double gap) => last.add(Duration(days: gap.round()));

  final dateBased = after(interval);
  var expected = dateBased;
  var earliest = after(_quantile(recentGaps, 0.25));
  var latest = after(_quantile(recentGaps, 0.75));

  final departed = _leftPump(stampByDay[last]!, placeVisits, placeNames);
  final since = _kmSinceRefuel(last, departed, activities, odometer, today);

  final distance = _distanceModel(
    days: days,
    amounts: byDay,
    typicalAmount: pastAmount,
    litres: litresByDay,
    typicalLitres: typicalLitres,
    lastRate: lastRate,
    activities: activities,
    odometer: odometer,
    kmSinceOverride: since,
    weekendDays: weekendDays,
    holidays: holidays,
    today: today,
    window: window,
  );
  if (distance != null) {
    expected = distance.expected;
    earliest = distance.earliest;
    latest = distance.latest;
  }

  return FuelForecast(
    lastRefuel: last,
    lastAmount: byDay[last]!,
    typicalIntervalDays: interval,
    typicalAmount: typicalAmount,
    expectedDate: expected,
    earliestDate: _min(earliest, expected),
    latestDate: _max(latest, expected),
    refuelCount: days.length,
    currency: currency,
    dateBasedExpectedDate: dateBased,
    distance: distance?.model,
    kmSinceRefuel: since,
    typicalLitres: typicalLitres,
    lastRatePerLitre: lastRate,
    lastRateDate: lastRateDate,
  );
}

const _pumpWords = [
  'petrol',
  'petorl',
  'fuel',
  'gas station',
  'filling station',
  'pump',
  'cng',
  'octane',
  'diesel',
];

bool _looksLikePump(TimelinePlaceVisit v, Map<String, String> names) {
  final text = [
    v.name,
    v.address,
    v.semanticType,
    if (v.placeId != null) names[v.placeId],
  ].whereType<String>().join(' ').toLowerCase();
  return _pumpWords.any(text.contains) || text.contains('gas_station');
}

/// When you rode away from the pump: the end of the timeline's pump visit
/// that day (the one nearest the payment). Without a pump visit it is the
/// payment time. A payment with no time of day matches any pump visit that
/// day and, lacking one, only gives the date.
DateTime _leftPump(
  DateTime paid,
  Iterable<TimelinePlaceVisit> visits,
  Map<String, String> names,
) {
  final hasTime = paid.hour != 0 || paid.minute != 0 || paid.second != 0;
  TimelinePlaceVisit? pump;
  Duration? gap;
  for (final v in visits) {
    if (!_looksLikePump(v, names)) continue;
    final start = v.startTime.toLocal();
    final end = v.endTime.toLocal();
    if (_dayOf(start) != _dayOf(paid) && _dayOf(end) != _dayOf(paid)) continue;
    final d = !hasTime
        ? Duration.zero
        : paid.isBefore(start)
        ? start.difference(paid)
        : paid.isAfter(end)
        ? paid.difference(end)
        : Duration.zero;
    if (hasTime && d > const Duration(hours: 3)) continue;
    // Several pump visits: the nearest payment, else the latest that day.
    if (pump == null ||
        d < gap! ||
        (d == gap && end.isAfter(pump.endTime.toLocal()))) {
      gap = d;
      pump = v;
    }
  }
  if (pump != null) return pump.endTime.toLocal();
  // No time of day and no pump visit: count from the next day, so the ride
  // to the pump is not included.
  return hasTime ? paid : _dayOf(paid).add(const Duration(days: 1));
}

/// Km ridden since leaving the pump at [left], up to [today].
///
/// With odometer readings logged after the refuel day, the odometer is the
/// truth for the stretch up to the latest reading. From there (or from the
/// pump itself when no later reading exists) the location timeline counts
/// rides that began after leaving, as recorded. Null when nothing covers the
/// refuel.
double? _kmSinceRefuel(
  DateTime refuel,
  DateTime left,
  Iterable<TimelineActivity> activities,
  OdometerLog odometer,
  DateTime today,
) {
  final latest = odometer.latest;
  final anchored =
      odometer.canMeasure && latest != null && latest.date.isAfter(refuel);
  // Timeline rides count after the later of the pump and the last reading.
  final from = anchored ? latest.date.add(const Duration(days: 1)) : left;
  DateTime? first;
  var km = 0.0;
  for (final a in activities) {
    final start = a.startTime.toLocal();
    if (first == null || start.isBefore(first)) first = start;
    if (a.isMotorcycling && a.distanceMeters > 0 && !start.isBefore(from)) {
      km += a.distanceMeters / 1000;
    }
  }
  if (anchored) {
    final base = odometer.kmBetween(refuel, latest.date, today);
    return base == null ? null : base + km;
  }
  if (first == null || _dayOf(first).isAfter(refuel)) return null;
  return km;
}

class _DistanceResult {
  const _DistanceResult(this.model, this.expected, this.earliest, this.latest);

  final FuelDistanceModel model;
  final DateTime expected;
  final DateTime earliest;
  final DateTime latest;
}

/// Recent weeks used to learn the riding pace for each weekday.
const _paceWindowDays = 56;

/// Furthest ahead the pace simulation looks.
const _maxLookaheadDays = 120;

_DistanceResult? _distanceModel({
  required List<DateTime> days,
  required Map<DateTime, double> amounts,
  required double typicalAmount,
  required Map<DateTime, double> litres,
  required double? typicalLitres,
  required double? lastRate,
  required Iterable<TimelineActivity> activities,
  required OdometerLog odometer,
  required double? kmSinceOverride,
  required List<int> weekendDays,
  required Set<DateTime> holidays,
  required DateTime today,
  required int window,
}) {
  DateTime? coverageStart;
  DateTime? coverageEnd;
  final kmByDay = <DateTime, double>{};
  for (final a in activities) {
    final start = _dayOf(a.startTime);
    final end = _dayOf(a.endTime);
    if (coverageStart == null || start.isBefore(coverageStart)) {
      coverageStart = start;
    }
    if (coverageEnd == null || end.isAfter(coverageEnd)) coverageEnd = end;
    if (a.isMotorcycling && a.distanceMeters > 0) {
      kmByDay[start] = (kmByDay[start] ?? 0) + a.distanceMeters / 1000;
    }
  }
  // Odometer readings count every km, so they replace recorded rides for
  // the totals; the rides still shape which weekdays are heavy.
  final odo = odometer.canMeasure && (odometer.dailyRate ?? 0) > 0
      ? odometer
      : null;
  final gpsStart = coverageStart;
  if (odo != null) {
    coverageStart = odo.readings.first.date;
    coverageEnd = today;
  }
  if (coverageStart == null ||
      coverageEnd == null ||
      (kmByDay.isEmpty && odo == null)) {
    return null;
  }
  final start0 = coverageStart;

  double kmBetween(DateTime afterDay, DateTime throughDay) {
    if (odo != null) return odo.kmBetween(afterDay, throughDay, today) ?? 0;
    var total = 0.0;
    for (final e in kmByDay.entries) {
      if (e.key.isAfter(afterDay) && !e.key.isAfter(throughDay)) {
        total += e.value;
      }
    }
    return total;
  }

  // What each past refill lasted: the refill at the end of a gap replaces
  // what the gap used, so km over that gap divided by that amount.
  final efficiencies = <double>[];
  final perLitre = <double>[];
  for (var i = 1; i < days.length; i++) {
    final start = days[i - 1];
    final end = days[i];
    if (start.isBefore(coverageStart) || end.isAfter(coverageEnd)) continue;
    final km = kmBetween(start, end);
    final amount = amounts[end] ?? 0;
    if (km <= 0 || amount <= 0) continue;
    efficiencies.add(km / amount);
    final l = litres[end];
    if (l != null && l > 0) perLitre.add(km / l);
  }
  // Litres are the better unit: a price change doesn't move them. Use them
  // when enough refuels carried a price, else fall back to currency.
  final useLitres =
      perLitre.length >= 2 && typicalLitres != null && lastRate != null;
  if (!useLitres && efficiencies.length < 2) return null;
  final basis = useLitres ? perLitre : efficiencies;
  final recentEff = basis.length > window
      ? basis.sublist(basis.length - window)
      : basis;

  final last = days.last;
  if (last.isBefore(coverageStart)) return null;
  final through = coverageEnd.isAfter(today) ? today : coverageEnd;
  final kmSince = kmSinceOverride ?? kmBetween(last, through);

  final efficiency = _quantile(recentEff, 0.5);
  final fill = useLitres ? typicalLitres : typicalAmount;
  final range = efficiency * fill;
  final rangeLow = _quantile(recentEff, 0.25) * fill;
  final rangeHigh = _quantile(recentEff, 0.75) * fill;

  // Riding pace for each weekday over recent weeks, kept apart for workdays
  // and days off (weekends and public holidays).
  bool off(DateTime d) =>
      isDayOffOn(d, weekendDays: weekendDays, holidays: holidays);
  final paceStart = through.subtract(const Duration(days: _paceWindowDays));
  // Index: day type (0 workday, 1 day off) * 8 + weekday.
  final kmOnKind = List<double>.filled(16, 0);
  final daysOnKind = List<int>.filled(16, 0);
  for (var i = 0; i < _paceWindowDays; i++) {
    final d = through.subtract(Duration(days: i));
    if (d.isBefore(paceStart) || d.isBefore(gpsStart ?? start0)) continue;
    final k = (off(d) ? 8 : 0) + d.weekday;
    daysOnKind[k]++;
    kmOnKind[k] += kmByDay[d] ?? 0;
  }
  final totalDays = daysOnKind.fold<int>(0, (a, b) => a + b);
  final gpsOverall = totalDays == 0
      ? 0.0
      : kmOnKind.fold<double>(0, (a, b) => a + b) / totalDays;
  final usableRides = totalDays >= 14 && gpsOverall > 0;
  if (odo == null && !usableRides) return null;
  final overall = odo?.dailyRate ?? gpsOverall;
  if (overall <= 0) return null;
  // Rides give the weekday shape; the odometer sets the level.
  final scale = odo != null && usableRides ? overall / gpsOverall : 1.0;
  // A weekday's own pace within its day type; a holiday on an odd weekday
  // has too few past samples, so it takes the pace of days off in general.
  double pace(DateTime d) {
    if (!usableRides) return overall;
    final base = off(d) ? 8 : 0;
    final own = base + d.weekday;
    if (daysOnKind[own] >= 3) return kmOnKind[own] / daysOnKind[own] * scale;
    var km = 0.0;
    var n = 0;
    for (var w = 1; w <= 7; w++) {
      km += kmOnKind[base + w];
      n += daysOnKind[base + w];
    }
    return n >= 3 ? km / n * scale : overall;
  }

  DateTime dateFor(double tankKm) {
    final left = tankKm - kmSince;
    if (left <= 0) return through;
    var acc = 0.0;
    var d = through;
    for (var i = 0; i < _maxLookaheadDays; i++) {
      d = d.add(const Duration(days: 1));
      acc += pace(d);
      if (acc >= left) return d;
    }
    return d;
  }

  return _DistanceResult(
    FuelDistanceModel(
      kmSinceLastRefuel: kmSince,
      tankRangeKm: range,
      kmLeft: (range - kmSince).clamp(0, double.infinity),
      kmPerCurrency: useLitres ? efficiency / lastRate : efficiency,
      kmPerLitre: useLitres ? efficiency : null,
      dailyKm: overall,
      gapsUsed: basis.length,
      locationThrough: through,
      fromOdometer: odo != null,
    ),
    dateFor(range),
    dateFor(rangeLow),
    dateFor(rangeHigh),
  );
}

DateTime _dayOf(DateTime d) {
  final local = d.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime _min(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
DateTime _max(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

/// Linear-interpolated quantile of [values] (non-empty).
double _quantile(List<double> values, double q) {
  final sorted = [...values]..sort();
  if (sorted.length == 1) return sorted.first;
  final pos = (sorted.length - 1) * q;
  final lo = pos.floor();
  final hi = pos.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}
