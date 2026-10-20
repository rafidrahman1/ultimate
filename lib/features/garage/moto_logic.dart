import 'package:motohealth/features/garage/moto_models.dart';

/// One known odometer value on a day, from any kind of entry.
typedef OdoPoint = ({DateTime date, double km});

/// Every odometer value known for [bike], oldest first: its starting value
/// plus plain readings, fuel and service entries.
List<OdoPoint> odometerPoints(MotoData data, Bike bike) {
  final points = <OdoPoint>[
    (date: dayOf(bike.addedOn), km: bike.startOdometer),
    for (final r in data.readings)
      if (r.bikeId == bike.id) (date: dayOf(r.date), km: r.km),
    for (final f in data.fuel)
      if (f.bikeId == bike.id && f.odometer != null)
        (date: dayOf(f.date), km: f.odometer!),
    for (final s in data.services)
      if (s.bikeId == bike.id && s.odometer != null)
        (date: dayOf(s.date), km: s.odometer!),
  ]..sort((a, b) => a.date.compareTo(b.date));
  return points;
}

/// Why [km] on [date] can't be right, or null when it fits the readings
/// around it. An odometer never runs backwards. [exceptId] leaves out the
/// entry being edited.
String? odometerProblem(
  MotoData data,
  Bike bike,
  DateTime date,
  double km, {
  String? exceptId,
}) {
  final day = dayOf(date);
  final others = <OdoPoint>[
    (date: dayOf(bike.addedOn), km: bike.startOdometer),
    for (final r in data.readings)
      if (r.bikeId == bike.id && r.id != exceptId)
        (date: dayOf(r.date), km: r.km),
    for (final f in data.fuel)
      if (f.bikeId == bike.id && f.id != exceptId && f.odometer != null)
        (date: dayOf(f.date), km: f.odometer!),
    for (final s in data.services)
      if (s.bikeId == bike.id && s.id != exceptId && s.odometer != null)
        (date: dayOf(s.date), km: s.odometer!),
  ];
  for (final p in others) {
    if (p.date.isBefore(day) && p.km > km) {
      return 'Lower than ${p.km.round()} km logged earlier';
    }
    if (p.date.isAfter(day) && p.km < km) {
      return 'Higher than ${p.km.round()} km logged later';
    }
  }
  return null;
}

/// The highest odometer value logged: an odometer never runs backwards, so a
/// lower value later on is a typo and is ignored.
double latestOdometer(MotoData data, Bike bike) {
  var km = bike.startOdometer;
  for (final p in odometerPoints(data, bike)) {
    if (p.km > km) km = p.km;
  }
  return km;
}

/// Km per day over the last [windowDays] days (all history when there is too
/// little in the window). Null with under a week of data.
double? dailyRate(MotoData data, Bike bike, DateTime today) {
  final points = odometerPoints(data, bike);
  if (points.length < 2) return null;
  final last = points.last;
  final windowStart = last.date.subtract(const Duration(days: 120));
  var inWindow = [
    for (final p in points)
      if (!p.date.isBefore(windowStart)) p,
  ];
  if (inWindow.length < 2) inWindow = points;
  final first = inWindow.first;
  final days = last.date.difference(first.date).inDays;
  if (days < 7) return null;
  final km = last.km - first.km;
  return km <= 0 ? 0 : km / days;
}

/// Best guess of the odometer today: the latest logged value plus the usual
/// riding since then.
double estimatedOdometer(MotoData data, Bike bike, DateTime today) {
  final points = odometerPoints(data, bike);
  final latest = latestOdometer(data, bike);
  final rate = dailyRate(data, bike, today);
  if (rate == null || points.isEmpty) return latest;
  final since = dayOf(today).difference(points.last.date).inDays;
  return since <= 0 ? latest : latest + rate * since;
}

// ---------------------------------------------------------------- fuel

/// Mileage of one stretch between two full tanks.
class FuelSegment {
  const FuelSegment({
    required this.endDate,
    required this.km,
    required this.litres,
    required this.cost,
  });

  final DateTime endDate;
  final double km;
  final double litres;
  final double cost;

  double get kmPerLitre => litres > 0 ? km / litres : 0;
  double get costPerKm => km > 0 ? cost / km : 0;
}

class FuelStats {
  const FuelStats({
    required this.segments,
    required this.totalLitres,
    required this.totalCost,
    required this.fills,
  });

  final List<FuelSegment> segments;
  final double totalLitres;
  final double totalCost;
  final int fills;

  double get _segKm => segments.fold(0, (s, e) => s + e.km);
  double get _segLitres => segments.fold(0, (s, e) => s + e.litres);
  double get _segCost => segments.fold(0, (s, e) => s + e.cost);

  /// Lifetime km per litre across all measured stretches.
  double? get averageKmPerLitre => _segLitres > 0 ? _segKm / _segLitres : null;
  double? get lastKmPerLitre =>
      segments.isEmpty ? null : segments.last.kmPerLitre;
  double? get bestKmPerLitre => segments.isEmpty
      ? null
      : segments.map((s) => s.kmPerLitre).reduce((a, b) => a > b ? a : b);
  double? get costPerKm => _segKm > 0 ? _segCost / _segKm : null;
  double? get averagePricePerLitre =>
      totalLitres > 0 ? totalCost / totalLitres : null;
}

/// Full-tank method: mileage is the km between two full fills divided by the
/// litres put in after the first of them, partial fills included. A fill
/// without an odometer can't start or end a stretch, but its litres still
/// count towards the stretch it falls in.
FuelStats fuelStats(Iterable<FuelEntry> entries) {
  final sorted = entries.toList()
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return (a.odometer ?? double.infinity).compareTo(
        b.odometer ?? double.infinity,
      );
    });
  final segments = <FuelSegment>[];
  FuelEntry? anchor;
  var litres = 0.0;
  var cost = 0.0;
  for (final e in sorted) {
    if (anchor != null) {
      litres += e.litres;
      cost += e.cost;
    }
    final odo = e.odometer;
    if (!e.fullTank || odo == null) continue;
    if (anchor != null && odo > anchor.odometer! && litres > 0) {
      segments.add(
        FuelSegment(
          endDate: e.date,
          km: odo - anchor.odometer!,
          litres: litres,
          cost: cost,
        ),
      );
    }
    anchor = e;
    litres = 0;
    cost = 0;
  }
  return FuelStats(
    segments: segments,
    totalLitres: sorted.fold(0, (s, e) => s + e.litres),
    totalCost: sorted.fold(0, (s, e) => s + e.cost),
    fills: sorted.length,
  );
}

// ------------------------------------------------------------- service

enum DueLevel { ok, soon, overdue }

class TaskStatus {
  const TaskStatus({
    required this.task,
    required this.level,
    this.lastDate,
    this.lastKm,
    this.kmLeft,
    this.daysLeft,
    this.dueKm,
    this.dueDate,
    this.neverDone = false,
  });

  final ServiceTask task;
  final DueLevel level;
  final DateTime? lastDate;
  final double? lastKm;

  /// Negative once past due. Null when the task has no km interval.
  final double? kmLeft;
  final int? daysLeft;
  final double? dueKm;
  final DateTime? dueDate;

  /// No service logged yet; counting from when the bike was added.
  final bool neverDone;

  /// 0 (just done) to 1 (due now) and beyond, whichever interval is nearer.
  double get used {
    var u = 0.0;
    final km = task.intervalKm;
    if (km != null && kmLeft != null) u = (km - kmLeft!) / km;
    final d = task.intervalDays;
    if (d != null && daysLeft != null) {
      final byDays = (d - daysLeft!) / d;
      if (byDays > u) u = byDays;
    }
    return u;
  }
}

/// Status of every maintenance task of [bike] as of [today].
List<TaskStatus> taskStatuses(MotoData data, Bike bike, DateTime today) {
  final odo = estimatedOdometer(data, bike, today);
  final day = dayOf(today);
  final services = data.services.where((s) => s.bikeId == bike.id).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return [
    for (final task in bike.tasks)
      _statusOf(task, services, data, bike, odo, day),
  ];
}

TaskStatus _statusOf(
  ServiceTask task,
  List<ServiceEntry> services,
  MotoData data,
  Bike bike,
  double odo,
  DateTime today,
) {
  ServiceEntry? last;
  for (final s in services) {
    if (s.taskIds.contains(task.id)) last = s;
  }
  final fromDate = last == null ? dayOf(bike.addedOn) : dayOf(last.date);
  final fromKm = last == null
      ? bike.startOdometer
      : last.odometer ?? _knownKmAt(data, bike, dayOf(last.date));

  final dueKm = task.intervalKm == null ? null : fromKm + task.intervalKm!;
  final dueDate = task.intervalDays == null
      ? null
      : fromDate.add(Duration(days: task.intervalDays!));
  final kmLeft = dueKm == null ? null : dueKm - odo;
  final daysLeft = dueDate?.difference(today).inDays;

  var level = DueLevel.ok;
  final kmSoon = task.intervalKm == null
      ? 0.0
      : (task.intervalKm! * 0.1).clamp(50, 500).toDouble();
  final daySoon = task.intervalDays == null
      ? 0
      : (task.intervalDays! * 0.1).clamp(7, 30).round();
  if ((kmLeft != null && kmLeft < 0) || (daysLeft != null && daysLeft < 0)) {
    level = DueLevel.overdue;
  } else if ((kmLeft != null && kmLeft <= kmSoon) ||
      (daysLeft != null && daysLeft <= daySoon)) {
    level = DueLevel.soon;
  }
  return TaskStatus(
    task: task,
    level: level,
    lastDate: last == null ? null : dayOf(last.date),
    lastKm: last?.odometer,
    kmLeft: kmLeft,
    daysLeft: daysLeft,
    dueKm: dueKm,
    dueDate: dueDate,
    neverDone: last == null,
  );
}

/// The highest odometer logged on or before [day], for a service saved
/// without one.
double _knownKmAt(MotoData data, Bike bike, DateTime day) {
  var km = bike.startOdometer;
  for (final p in odometerPoints(data, bike)) {
    if (!p.date.isAfter(day) && p.km > km) km = p.km;
  }
  return km;
}

/// The date a task falls due, whichever comes first: its own date interval or
/// when the riding pace reaches its km interval.
DateTime? expectedDueDate(TaskStatus s, double? kmPerDay, DateTime today) {
  DateTime? best = s.dueDate;
  final kmLeft = s.kmLeft;
  if (kmLeft != null && kmPerDay != null && kmPerDay > 0) {
    final byKm = dayOf(today).add(Duration(days: (kmLeft / kmPerDay).ceil()));
    if (best == null || byKm.isBefore(best)) best = byKm;
  }
  return best;
}

// -------------------------------------------------------------- papers

enum PaperLevel { valid, soon, expired }

int paperDaysLeft(Paper p, DateTime today) =>
    dayOf(p.expiry).difference(dayOf(today)).inDays;

PaperLevel paperLevel(Paper p, DateTime today) {
  final d = paperDaysLeft(p, today);
  if (d < 0) return PaperLevel.expired;
  return d <= 30 ? PaperLevel.soon : PaperLevel.valid;
}

// -------------------------------------------------------------- health

/// 0–100 summary: how much of the maintenance is up to date (70%) and
/// whether the papers are valid (30%). Jobs that are due soon count half.
int healthScore(List<TaskStatus> tasks, List<Paper> papers, DateTime today) {
  double part(Iterable<double> values) =>
      values.isEmpty ? 1 : values.reduce((a, b) => a + b) / values.length;
  final maintenance = part([
    for (final t in tasks)
      switch (t.level) {
        DueLevel.ok => 1.0,
        DueLevel.soon => 0.5,
        DueLevel.overdue => 0.0,
      },
  ]);
  final documents = part([
    for (final p in papers)
      switch (paperLevel(p, today)) {
        PaperLevel.valid => 1.0,
        PaperLevel.soon => 0.5,
        PaperLevel.expired => 0.0,
      },
  ]);
  if (papers.isEmpty) return (maintenance * 100).round();
  return ((maintenance * 0.7 + documents * 0.3) * 100).round();
}

// --------------------------------------------------------------- costs

/// Money spent by label ("Fuel", "Service", expense categories) for one bike.
Map<String, double> costByCategory(
  MotoData data,
  Bike bike, {
  DateTime? from,
  DateTime? to,
}) {
  bool inRange(DateTime d) =>
      (from == null || !d.isBefore(from)) && (to == null || d.isBefore(to));
  final out = <String, double>{};
  void add(String key, double v) => out[key] = (out[key] ?? 0) + v;
  for (final f in data.fuel) {
    if (f.bikeId == bike.id && inRange(f.date)) add('Fuel', f.cost);
  }
  for (final s in data.services) {
    if (s.bikeId == bike.id && inRange(s.date)) add('Service', s.cost);
  }
  for (final e in data.expenses) {
    if (e.bikeId == bike.id && inRange(e.date)) add(e.category.label, e.amount);
  }
  return out;
}

double totalCost(Map<String, double> byCategory) =>
    byCategory.values.fold(0, (a, b) => a + b);
