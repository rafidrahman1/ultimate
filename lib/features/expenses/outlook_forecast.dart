import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_insights.dart';
import 'package:personal/features/expenses/recurring_forecast.dart';
import 'package:personal/features/location/timeline_activity.dart';

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
  final dailyRate = projection.typicalMonth / projection.daysInMonth;

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
  });

  final String label;
  final DateTime expectedDate;
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
  final groups = <String, List<CashewTransaction>>{};
  for (final t in transactions) {
    if (!t.isRealIncome) continue;
    final title = t.title?.trim().toLowerCase() ?? '';
    if (title.isEmpty) continue;
    groups.putIfAbsent(title, () => []).add(t);
  }

  UpcomingCharge? best;
  for (final entries in groups.values) {
    final found = inferRepeatingEntry(entries, now: today);
    if (found == null) continue;
    if (best == null || found.amount > best.amount) best = found;
  }
  if (best == null) return null;

  final days = best.expectedDate.difference(today).inDays;
  if (days > horizonDays) return null;

  final dailyRate = projection == null
      ? 0.0
      : projection.typicalMonth / projection.daysInMonth;
  final bills = upcoming
      .where((c) => !c.expectedDate.isAfter(best!.expectedDate))
      .fold<double>(0, (sum, c) => sum + c.amount);
  return PaydayOutlook(
    label: best.label,
    expectedDate: best.expectedDate,
    amount: best.amount,
    expectedSpend: dailyRate * (days < 0 ? 0 : days),
    billsBefore: bills,
    daysUntil: days,
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
}) => _forecastMaintenance(
  BikeMaintenance.service,
  transactions.where(_isServiceEntry),
  activities,
  now,
);

BikeServiceForecast? forecastBikeOilChange(
  Iterable<CashewTransaction> transactions,
  Iterable<TimelineActivity> activities, {
  DateTime? now,
}) => _forecastMaintenance(
  BikeMaintenance.oil,
  transactions.where(_isOilEntry),
  activities,
  now,
);

BikeServiceForecast? _forecastMaintenance(
  BikeMaintenance kind,
  Iterable<CashewTransaction> entries,
  Iterable<TimelineActivity> activities,
  DateTime? now,
) {
  final today = _dayOf(now ?? DateTime.now());
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
  if (rides.isEmpty) {
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
  final firstRide = rides
      .map((r) => r.$1)
      .reduce((a, b) => a.isBefore(b) ? a : b);

  double kmBetween(DateTime from, DateTime to) => rides
      .where((r) => !r.$1.isBefore(from) && r.$1.isBefore(to))
      .fold<double>(0, (sum, r) => sum + r.$2);

  final kmSince = kmBetween(last, today.add(const Duration(days: 1)));

  // Gaps between entries, only where location data covers the whole gap.
  final gaps = <double>[
    for (var i = 1; i < days.length; i++)
      if (!days[i - 1].add(const Duration(days: 7)).isBefore(firstRide))
        kmBetween(days[i - 1], days[i]),
  ].where((km) => km > 0).toList();
  final interval = gaps.length >= 2 ? _median(gaps) : null;

  final recentStart = today.subtract(const Duration(days: 56));
  final dailyKm =
      kmBetween(recentStart, today.add(const Duration(days: 1))) / 56;

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
    category: category,
  );
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
