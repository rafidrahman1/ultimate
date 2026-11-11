import 'package:clock/clock.dart';
import 'package:personal/features/bike/data/odometer_service.dart';
import 'package:personal/features/expenses/analysis/expense_insights.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/forecasts/outlook/recurring_forecast.dart';
import 'package:personal/features/location/data/timeline_activity.dart';

// ── Budget runout ────────────────────────────────────────────────────────

/// When this month's budget runs out at a normal day's spending.
class BudgetOutlook {
  const BudgetOutlook({
    required this.budget,
    required this.spent,
    required this.projected,
    required this.runoutDate,
  });

  final double budget;
  final double spent;

  /// Where the month ends up, from [MonthProjection].
  final double projected;

  /// The day the budget is used up. Null when it lasts the month.
  final DateTime? runoutDate;

  bool get isOver => spent >= budget;
  bool get lastsMonth => !isOver && runoutDate == null;
  double get left => budget - spent;
}

BudgetOutlook? forecastBudgetRunout({
  required double? budget,
  required MonthProjection? projection,
  required DateTime now,
}) {
  if (budget == null || budget <= 0 || projection == null) return null;
  final today = DateTime(now.year, now.month, now.day);
  final spent = projection.spentSoFar;
  final dailyRate = projection.remainingDailyRate;

  DateTime? runout;
  if (spent >= budget) {
    runout = today;
  } else if (projection.projected > budget && dailyRate > 0) {
    final days = ((budget - spent) / dailyRate).ceil();
    runout = today.add(Duration(days: days));
    // Past the last day of the month means it lasts the month.
    if (runout.month != today.month) runout = null;
  }
  return BudgetOutlook(
    budget: budget,
    spent: spent,
    projected: projection.projected,
    runoutDate: runout,
  );
}

// ── Next income ──────────────────────────────────────────────────────────

/// The next salary or other income, and what a normal stretch of spending
/// looks like until it lands.
class PaydayOutlook {
  const PaydayOutlook({
    required this.label,
    required this.expectedDate,
    required this.amount,
    required this.expectedSpend,
    required this.billsBefore,
    required this.daysUntil,
    this.earliestDate,
  });

  final String label;
  final DateTime expectedDate;

  /// The working day before, when the usual date falls on a Friday or
  /// Saturday and pay may come early (Thursday) instead of after the weekend
  /// ([expectedDate], Sunday). Null when the usual date is a working day.
  final DateTime? earliestDate;
  final double amount;

  /// A normal day's spending times the days until payday.
  final double expectedSpend;

  /// Known bills falling before payday (already inside [expectedSpend]).
  final double billsBefore;
  final int daysUntil;
}

/// Finds income that repeats at a steady gap, picks the largest, and sizes up
/// the wait for it. Null with no regular income or when payday is far off.
PaydayOutlook? forecastPayday(
  Iterable<CashewTransaction> transactions, {
  required MonthProjection? projection,
  required List<UpcomingCharge> upcoming,
  required DateTime now,
  int horizonDays = 45,
}) {
  final today = DateTime(now.year, now.month, now.day);
  // Predicted from the last 6 months of pay; at least 3 payments needed.
  // Only the category matters, not the title: "Cash in" › "Salary".
  final since = DateTime(today.year, today.month - 6, today.day);
  final salary = [
    for (final t in transactions)
      if (!t.date.toLocal().isBefore(since) &&
          t.isRealIncome &&
          t.subcategory?.trim().toLowerCase() == 'salary')
        t,
  ];
  final best = salary.isEmpty
      ? null
      : inferRepeatingEntry(
              salary,
              now: today,
              minRepeats: 3,
              label: 'Salary',
            ) ??
            _monthlySalary(salary, today);
  if (best == null) return null;

  // Banks in Bangladesh are shut Friday and Saturday, so pay never lands then:
  // it arrives on the next working day (Sunday) or just before (Thursday).
  final payDate = nextBankDay(best.expectedDate);
  final early = previousBankDay(best.expectedDate);
  final earliest = payDate == best.expectedDate || early.isBefore(today)
      ? null
      : early;
  final days = payDate.difference(today).inDays;
  if (days > horizonDays) return null;

  final dailyRate = projection == null
      ? 0.0
      : projection.typicalMonth / projection.daysInMonth;
  final bills = upcoming
      .where((c) => !c.expectedDate.isAfter(payDate))
      .fold<double>(0, (sum, c) => sum + c.amount);
  return PaydayOutlook(
    label: best.label,
    expectedDate: payDate,
    amount: best.amount,
    expectedSpend: dailyRate * (days < 0 ? 0 : days),
    billsBefore: bills,
    daysUntil: days,
    earliestDate: earliest,
  );
}

/// [date], or the Thursday before when it falls on a Friday or Saturday.
DateTime previousBankDay(DateTime date) {
  var d = DateTime(date.year, date.month, date.day);
  while (d.weekday == DateTime.friday || d.weekday == DateTime.saturday) {
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return d;
}

/// [date], or the Sunday after when it falls on a Friday or Saturday.
DateTime nextBankDay(DateTime date) {
  var d = DateTime(date.year, date.month, date.day);
  while (d.weekday == DateTime.friday || d.weekday == DateTime.saturday) {
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return d;
}

/// Pay that lands once a month but on a drifting day (weekends, holidays), so
/// the gaps between payments are too uneven for [inferRepeatingEntry]. Uses
/// the usual day of the month instead. Needs pay in 3 different months.
UpcomingCharge? _monthlySalary(List<CashewTransaction> salary, DateTime today) {
  final byMonth = <int, List<CashewTransaction>>{};
  for (final t in salary) {
    final d = _dayOf(t.date);
    byMonth.putIfAbsent(d.year * 12 + d.month, () => []).add(t);
  }
  if (byMonth.length < 3) return null;
  final months = byMonth.keys.toList()..sort();
  final recent = months.length > 6 ? months.sublist(months.length - 6) : months;

  // Evenly spread across months: no skipped month in the recent run.
  if (recent.last - recent.first != recent.length - 1) return null;

  final totals = [
    for (final m in recent)
      byMonth[m]!.fold<double>(0, (s, t) => s + t.amount.abs()),
  ];
  final typical = _median(totals);
  if (typical <= 0) return null;
  if (totals.any((a) => (a - typical).abs() > typical * 0.5)) return null;

  final usualDay = _median([
    for (final m in recent) _dayOf(byMonth[m]!.first.date).day.toDouble(),
  ]).round();
  DateTime inMonth(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, usualDay > lastDay ? lastDay : usualDay);
  }

  final last = byMonth[recent.last]!
      .map((t) => _dayOf(t.date))
      .reduce((a, b) => a.isAfter(b) ? a : b);
  // The month after the latest payment. Late pay stays on show as overdue;
  // null only once it is 3 weeks late, i.e. the pay has lapsed.
  final next = inMonth(last.year, last.month + 1);
  if (today.difference(next).inDays > 21) return null;

  return UpcomingCharge(
    label: 'Salary',
    cadence: 'monthly',
    amount: typical,
    expectedDate: next,
    lastDate: last,
    count: byMonth.length,
    declared: false,
  );
}

// ── Bike maintenance ─────────────────────────────────────────────────────

/// A kind of bike maintenance with its own history and prediction.
enum BikeMaintenance { service, oil }

/// When the bike is next due for [kind], from km ridden since the last one,
/// or from the usual gap in days when there is no riding data.
class BikeServiceForecast {
  const BikeServiceForecast({
    required this.kind,
    required this.lastDone,
    required this.kmSince,
    required this.dailyKm,
    required this.count,
    this.hasRiding = true,
    this.intervalKm,
    this.intervalDays,
    this.kmLeft,
    this.expectedDate,
    this.partialData = false,
    this.fromOdometer = false,
    this.category,
  });

  final BikeMaintenance kind;

  /// The expense category most of these entries are filed under, e.g.
  /// "Vespa". It often names the bike.
  final String? category;
  final DateTime lastDone;
  final double kmSince;
  final double dailyKm;

  /// Entries found, one per day.
  final int count;

  /// False when no motorcycle trips were found, so km figures are blank.
  final bool hasRiding;

  /// Usual km between entries. Null with fewer than two measurable gaps.
  final double? intervalKm;

  /// Usual days between entries. Null with fewer than two gaps.
  final int? intervalDays;
  final double? kmLeft;
  final DateTime? expectedDate;

  /// Location data starts after the last entry, so [kmSince] undercounts.
  final bool partialData;

  /// Km come from the odometer readings rather than recorded rides.
  final bool fromOdometer;

  bool get isOverdue => kmLeft != null && kmLeft! < 0;
  String get noun => kind == BikeMaintenance.oil ? 'oil change' : 'service';
}

/// Engine oil, by its title.
bool _isOilEntry(CashewTransaction t) {
  if (!t.isRealExpense || ExpensesSummary.isFuelExpense(t)) return false;
  return RegExp(
    r'engine oil|oil change',
  ).hasMatch(t.title?.toLowerCase() ?? '');
}

/// A bike service: the title must say "servicing". "Service", maintenance or
/// repair categories and titles naming the bike are deliberately not enough.
bool _isServiceEntry(CashewTransaction t) {
  if (!t.isRealExpense || ExpensesSummary.isFuelExpense(t)) return false;
  return RegExp(r'\bservicing\b').hasMatch(t.title?.toLowerCase() ?? '');
}

BikeServiceForecast? forecastBikeService(
  Iterable<CashewTransaction> transactions,
  Iterable<TimelineActivity> activities, {
  DateTime? now,
  OdometerLog odometer = OdometerLog.empty,
}) => _forecastMaintenance(
  BikeMaintenance.service,
  transactions.where(_isServiceEntry),
  activities,
  now,
  odometer,
);

BikeServiceForecast? forecastBikeOilChange(
  Iterable<CashewTransaction> transactions,
  Iterable<TimelineActivity> activities, {
  DateTime? now,
  OdometerLog odometer = OdometerLog.empty,
}) => _forecastMaintenance(
  BikeMaintenance.oil,
  transactions.where(_isOilEntry),
  activities,
  now,
  odometer,
);

BikeServiceForecast? _forecastMaintenance(
  BikeMaintenance kind,
  Iterable<CashewTransaction> entries,
  Iterable<TimelineActivity> activities,
  DateTime? now,
  OdometerLog odometer,
) {
  final today = _dayOf(now ?? clock.now());
  final list = entries.toList();
  final category = _mostCommonCategory(list);
  final days = {for (final t in list) _dayOf(t.date)}.toList()..sort();
  if (days.isEmpty) return null;
  final last = days.last;

  // Usual gap in days, the fallback when there is no riding data.
  final dayGaps = <double>[
    for (var i = 1; i < days.length; i++)
      days[i].difference(days[i - 1]).inDays.toDouble(),
  ].where((d) => d > 0).toList();
  final intervalDays = dayGaps.length >= 2 ? _median(dayGaps).round() : null;
  DateTime? dateFromDays() {
    if (intervalDays == null) return null;
    final due = last.add(Duration(days: intervalDays));
    return due.isBefore(today) ? today : due;
  }

  final rides = <(DateTime, double)>[
    for (final a in activities)
      if (a.isMotorcycling && a.distanceMeters > 0)
        (_dayOf(a.startTime), a.distanceMeters / 1000),
  ];
  final odo = odometer.canMeasure ? odometer : null;
  if (rides.isEmpty && odo == null) {
    return BikeServiceForecast(
      kind: kind,
      lastDone: last,
      kmSince: 0,
      dailyKm: 0,
      count: days.length,
      hasRiding: false,
      intervalDays: intervalDays,
      expectedDate: dateFromDays(),
      category: category,
    );
  }
  // Odometer readings beat recorded rides: they count every km, not only
  // the trips the timeline caught.
  final firstRide = odo != null
      ? odo.readings.first.date
      : rides.map((r) => r.$1).reduce((a, b) => a.isBefore(b) ? a : b);

  double kmBetween(DateTime from, DateTime to) => odo != null
      ? odo.kmBetween(from, to, today) ?? 0
      : rides
            .where((r) => !r.$1.isBefore(from) && r.$1.isBefore(to))
            .fold<double>(0, (sum, r) => sum + r.$2);

  // An odometer reading in an entry's note is exact, so it beats estimating
  // the km between that day and now.
  final noted = <DateTime, double>{
    for (final t in list) _dayOf(t.date): ?_noteOdometerKm(t),
  };
  final nowKm = odo?.kmAt(today, today);
  final lastNoted = noted[last];
  final kmSince = odo != null && nowKm != null && lastNoted != null
      ? (nowKm - lastNoted).clamp(0, double.infinity).toDouble()
      : kmBetween(last, today.add(const Duration(days: 1)));

  // Gaps between entries, only where location data covers the whole gap.
  final gaps = <double>[
    for (var i = 1; i < days.length; i++)
      if (!days[i - 1].add(const Duration(days: 7)).isBefore(firstRide))
        kmBetween(days[i - 1], days[i]),
  ].where((km) => km > 0).toList();
  final notedDays = noted.keys.toList()..sort();
  final notedGaps = <double>[
    for (var i = 1; i < notedDays.length; i++)
      noted[notedDays[i]]! - noted[notedDays[i - 1]]!,
  ].where((km) => km > 0).toList();
  final interval = notedGaps.length >= 2
      ? _median(notedGaps)
      : gaps.length >= 2
      ? _median(gaps)
      : null;

  final recentStart = today.subtract(const Duration(days: 56));
  final dailyKm = odo != null
      ? odo.dailyRate ?? 0
      : kmBetween(recentStart, today.add(const Duration(days: 1))) / 56;

  double? kmLeft;
  DateTime? due;
  if (interval != null) {
    kmLeft = interval - kmSince;
    if (dailyKm > 0) {
      final daysLeft = (kmLeft / dailyKm).ceil();
      due = today.add(Duration(days: daysLeft < 0 ? 0 : daysLeft));
      if (daysLeft > 365) due = null;
    }
  }

  return BikeServiceForecast(
    kind: kind,
    lastDone: last,
    kmSince: kmSince,
    dailyKm: dailyKm,
    count: days.length,
    intervalKm: interval,
    intervalDays: intervalDays,
    kmLeft: kmLeft,
    expectedDate: due ?? (interval == null ? dateFromDays() : null),
    partialData: firstRide.isAfter(last.add(const Duration(days: 7))),
    fromOdometer: odo != null,
    category: category,
  );
}

/// The odometer reading written in an entry's note, e.g. "12,450 km".
double? _noteOdometerKm(CashewTransaction t) {
  final m = RegExp(
    r'(\d{1,3}(?:[,\s]\d{3})+|\d{3,7})(?:\.\d+)?',
  ).firstMatch(t.note ?? '');
  if (m == null) return null;
  return double.tryParse(m.group(1)!.replaceAll(RegExp(r'[,\s]'), ''));
}

String? _mostCommonCategory(List<CashewTransaction> entries) {
  final counts = <String, int>{};
  for (final t in entries) {
    final c = t.category?.trim() ?? '';
    if (c.isNotEmpty) counts[c] = (counts[c] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

DateTime _dayOf(DateTime d) {
  final local = d.toLocal();
  return DateTime(local.year, local.month, local.day);
}
