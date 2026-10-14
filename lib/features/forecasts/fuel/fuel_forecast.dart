import 'package:personal/core/schedule/day_off.dart';
import 'package:personal/features/bike/odometer_service.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/location/data/timeline_activity.dart';

part 'fuel_forecast_distance.dart';

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
