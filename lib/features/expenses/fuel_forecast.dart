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
  DateTime? now,
  int minRefuels = 3,
  int window = 6,
}) {
  final today = _dayOf(now ?? DateTime.now());
  final byDay = <DateTime, double>{};
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

  final distance = _distanceModel(
    days: days,
    amounts: byDay,
    typicalAmount: pastAmount,
    litres: litresByDay,
    typicalLitres: typicalLitres,
    lastRate: lastRate,
    activities: activities,
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
    typicalLitres: typicalLitres,
    lastRatePerLitre: lastRate,
    lastRateDate: lastRateDate,
  );
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
  if (coverageStart == null || coverageEnd == null || kmByDay.isEmpty) {
    return null;
  }

  double kmBetween(DateTime afterDay, DateTime throughDay) {
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
  final kmSince = kmBetween(last, through);

  final efficiency = _quantile(recentEff, 0.5);
  final fill = useLitres ? typicalLitres : typicalAmount;
  final range = efficiency * fill;
  final rangeLow = _quantile(recentEff, 0.25) * fill;
  final rangeHigh = _quantile(recentEff, 0.75) * fill;

  // Riding pace for each weekday over recent weeks.
  final paceStart = through.subtract(const Duration(days: _paceWindowDays));
  final kmOnWeekday = List<double>.filled(8, 0);
  final daysOnWeekday = List<int>.filled(8, 0);
  for (var i = 0; i < _paceWindowDays; i++) {
    final d = through.subtract(Duration(days: i));
    if (d.isBefore(paceStart) || d.isBefore(coverageStart)) continue;
    daysOnWeekday[d.weekday]++;
    kmOnWeekday[d.weekday] += kmByDay[d] ?? 0;
  }
  final totalDays = daysOnWeekday.fold<int>(0, (a, b) => a + b);
  if (totalDays < 14) return null;
  final overall = kmOnWeekday.fold<double>(0, (a, b) => a + b) / totalDays;
  if (overall <= 0) return null;
  double pace(int weekday) => daysOnWeekday[weekday] >= 3
      ? kmOnWeekday[weekday] / daysOnWeekday[weekday]
      : overall;

  DateTime dateFor(double tankKm) {
    final left = tankKm - kmSince;
    if (left <= 0) return through;
    var acc = 0.0;
    var d = through;
    for (var i = 0; i < _maxLookaheadDays; i++) {
      d = d.add(const Duration(days: 1));
      acc += pace(d.weekday);
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
