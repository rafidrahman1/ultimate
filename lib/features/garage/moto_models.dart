DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

/// A recurring maintenance job with how often it comes round. Either interval
/// may be absent; whichever is reached first makes the job due.
class ServiceTask {
  const ServiceTask({
    required this.id,
    required this.name,
    this.intervalKm,
    this.intervalDays,
    this.note = '',
  });

  factory ServiceTask.fromJson(Map<String, dynamic> j) => ServiceTask(
    id: j['id'] as String,
    name: j['name'] as String,
    intervalKm: (j['intervalKm'] as num?)?.toDouble(),
    intervalDays: j['intervalDays'] as int?,
    note: j['note'] as String? ?? '',
  );

  final String id;
  final String name;
  final double? intervalKm;
  final int? intervalDays;

  /// Spec or advice for the job, e.g. the oil grade and quantity.
  final String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'intervalKm': intervalKm,
    'intervalDays': intervalDays,
    'note': note,
  };
}

class Bike {
  const Bike({
    required this.id,
    required this.name,
    required this.addedOn,
    required this.startOdometer,
    required this.tasks,
    this.make = '',
    this.model = '',
    this.year,
    this.plate = '',
    this.variant = '',
    this.engineCc,
    this.usage = '',
    this.conditions = '',
  });

  factory Bike.fromJson(Map<String, dynamic> j) => Bike(
    id: j['id'] as String,
    name: j['name'] as String,
    make: j['make'] as String? ?? '',
    model: j['model'] as String? ?? '',
    year: j['year'] as int?,
    plate: j['plate'] as String? ?? '',
    variant: j['variant'] as String? ?? '',
    engineCc: (j['engineCc'] as num?)?.toDouble(),
    usage: j['usage'] as String? ?? '',
    conditions: j['conditions'] as String? ?? '',
    addedOn: DateTime.parse(j['addedOn'] as String),
    startOdometer: (j['startOdometer'] as num).toDouble(),
    tasks: [
      for (final t in j['tasks'] as List? ?? const [])
        ServiceTask.fromJson(t as Map<String, dynamic>),
    ],
  );

  final String id;
  final String name;
  final String make;
  final String model;
  final int? year;
  final String plate;

  /// Trim or engine variant, e.g. "SP 125, fuel injected, ABS".
  final String variant;
  final double? engineCc;

  /// How the bike is used: city commuting, mixed, highway touring, off-road.
  final String usage;

  /// Climate, roads and habits that wear the bike, e.g. "humid, dusty, stop
  /// and go traffic". Passed to the AI so intervals fit the real conditions.
  final String conditions;

  /// The day the bike was added, and its odometer then. Service intervals
  /// count from here until the first service is logged.
  final DateTime addedOn;
  final double startOdometer;
  final List<ServiceTask> tasks;

  String get subtitle => [
    if (make.isNotEmpty || model.isNotEmpty) '$make $model'.trim(),
    if (year != null) '$year',
    if (plate.isNotEmpty) plate,
  ].join(' · ');

  /// Make, model, year and variant on one line, for prompts.
  String get fullName => [
    if (year != null) '$year',
    make,
    model,
    if (variant.isNotEmpty) variant,
  ].where((e) => e.isNotEmpty).join(' ');

  Bike copyWith({
    String? name,
    String? make,
    String? model,
    int? year,
    String? plate,
    String? variant,
    double? engineCc,
    String? usage,
    String? conditions,
    double? startOdometer,
    List<ServiceTask>? tasks,
  }) => Bike(
    id: id,
    name: name ?? this.name,
    make: make ?? this.make,
    model: model ?? this.model,
    year: year ?? this.year,
    plate: plate ?? this.plate,
    variant: variant ?? this.variant,
    engineCc: engineCc ?? this.engineCc,
    usage: usage ?? this.usage,
    conditions: conditions ?? this.conditions,
    addedOn: addedOn,
    startOdometer: startOdometer ?? this.startOdometer,
    tasks: tasks ?? this.tasks,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'make': make,
    'model': model,
    'year': year,
    'plate': plate,
    'variant': variant,
    'engineCc': engineCc,
    'usage': usage,
    'conditions': conditions,
    'addedOn': addedOn.toIso8601String(),
    'startOdometer': startOdometer,
    'tasks': [for (final t in tasks) t.toJson()],
  };
}

/// A plain odometer note, for days with no fuel or service entry.
class OdometerReading {
  const OdometerReading({
    required this.id,
    required this.bikeId,
    required this.date,
    required this.km,
  });

  factory OdometerReading.fromJson(Map<String, dynamic> j) => OdometerReading(
    id: j['id'] as String,
    bikeId: j['bikeId'] as String,
    date: DateTime.parse(j['date'] as String),
    km: (j['km'] as num).toDouble(),
  );

  final String id;
  final String bikeId;
  final DateTime date;
  final double km;

  Map<String, dynamic> toJson() => {
    'id': id,
    'bikeId': bikeId,
    'date': date.toIso8601String(),
    'km': km,
  };
}

/// What went in the tank. Petrol and octane are the two pumps bikes use.
enum FuelType {
  petrol('Petrol'),
  octane('Octane');

  const FuelType(this.label);
  final String label;
}

class FuelEntry {
  const FuelEntry({
    required this.id,
    required this.bikeId,
    required this.date,
    this.odometer,
    required this.litres,
    required this.cost,
    this.fullTank = true,
    this.station = '',
    this.fuelType,
  });

  factory FuelEntry.fromJson(Map<String, dynamic> j) => FuelEntry(
    id: j['id'] as String,
    bikeId: j['bikeId'] as String,
    date: DateTime.parse(j['date'] as String),
    odometer: (j['odometer'] as num?)?.toDouble(),
    litres: (j['litres'] as num).toDouble(),
    cost: (j['cost'] as num).toDouble(),
    fullTank: j['fullTank'] as bool? ?? true,
    station: j['station'] as String? ?? '',
    fuelType: FuelType.values.where((t) => t.name == j['fuelType']).firstOrNull,
  );

  final String id;
  final String bikeId;
  final DateTime date;

  /// Null when the rider didn't note it.
  final double? odometer;
  final double litres;
  final double cost;

  /// Filled to the brim. Mileage is measured between two full fills.
  final bool fullTank;
  final String station;
  final FuelType? fuelType;

  double get pricePerLitre => litres > 0 ? cost / litres : 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'bikeId': bikeId,
    'date': date.toIso8601String(),
    'odometer': odometer,
    'litres': litres,
    'cost': cost,
    'fullTank': fullTank,
    'station': station,
    'fuelType': fuelType?.name,
  };
}

class ServiceEntry {
  const ServiceEntry({
    required this.id,
    required this.bikeId,
    required this.date,
    this.odometer,
    required this.title,
    required this.cost,
    this.taskIds = const [],
    this.notes = '',
    this.shop = '',
  });

  factory ServiceEntry.fromJson(Map<String, dynamic> j) => ServiceEntry(
    id: j['id'] as String,
    bikeId: j['bikeId'] as String,
    date: DateTime.parse(j['date'] as String),
    odometer: (j['odometer'] as num?)?.toDouble(),
    title: j['title'] as String,
    cost: (j['cost'] as num).toDouble(),
    taskIds: [for (final t in j['taskIds'] as List? ?? const []) t as String],
    notes: j['notes'] as String? ?? '',
    shop: j['shop'] as String? ?? '',
  );

  final String id;
  final String bikeId;
  final DateTime date;

  /// Null when the rider didn't note it.
  final double? odometer;
  final String title;
  final double cost;

  /// The recurring jobs this visit did, which reset their countdowns.
  final List<String> taskIds;
  final String notes;
  final String shop;

  Map<String, dynamic> toJson() => {
    'id': id,
    'bikeId': bikeId,
    'date': date.toIso8601String(),
    'odometer': odometer,
    'title': title,
    'cost': cost,
    'taskIds': taskIds,
    'notes': notes,
    'shop': shop,
  };
}

enum ExpenseCategory {
  insurance('Insurance'),
  gear('Riding gear'),
  accessories('Accessories'),
  parking('Parking & tolls'),
  fines('Fines & fees'),
  wash('Wash & care'),
  other('Other');

  const ExpenseCategory(this.label);
  final String label;
}

class Expense {
  const Expense({
    required this.id,
    required this.bikeId,
    required this.date,
    required this.category,
    required this.amount,
    this.note = '',
  });

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'] as String,
    bikeId: j['bikeId'] as String,
    date: DateTime.parse(j['date'] as String),
    category: ExpenseCategory.values.firstWhere(
      (c) => c.name == j['category'],
      orElse: () => ExpenseCategory.other,
    ),
    amount: (j['amount'] as num).toDouble(),
    note: j['note'] as String? ?? '',
  );

  final String id;
  final String bikeId;
  final DateTime date;
  final ExpenseCategory category;
  final double amount;
  final String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'bikeId': bikeId,
    'date': date.toIso8601String(),
    'category': category.name,
    'amount': amount,
    'note': note,
  };
}

/// The papers a Bangladeshi rider keeps current (BRTA). Stored by name, so
/// [roadTax] is the tax token and [pollution] stays only for older saves.
enum PaperType {
  registration('Registration certificate', 60),
  roadTax('Tax token', 12),
  fitness('Fitness certificate', 12),
  insurance('Insurance', 12),
  licence('Driving licence', 60),
  other('Other', 12),
  pollution('Emission certificate', 12);

  const PaperType(this.label, this.typicalMonths);
  final String label;

  /// Usual validity, to suggest an expiry date for a new document.
  final int typicalMonths;

  /// Offered when adding a document; [pollution] is kept for old entries.
  static const choices = [
    registration,
    roadTax,
    fitness,
    insurance,
    licence,
    other,
  ];
}

/// A document that expires and has to be renewed.
class Paper {
  const Paper({
    required this.id,
    required this.bikeId,
    required this.type,
    required this.expiry,
    this.number = '',
    this.note = '',
  });

  factory Paper.fromJson(Map<String, dynamic> j) => Paper(
    id: j['id'] as String,
    bikeId: j['bikeId'] as String,
    type: PaperType.values.firstWhere(
      (c) => c.name == j['type'],
      orElse: () => PaperType.other,
    ),
    expiry: DateTime.parse(j['expiry'] as String),
    number: j['number'] as String? ?? '',
    note: j['note'] as String? ?? '',
  );

  final String id;
  final String bikeId;
  final PaperType type;
  final DateTime expiry;
  final String number;
  final String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'bikeId': bikeId,
    'type': type.name,
    'expiry': expiry.toIso8601String(),
    'number': number,
    'note': note,
  };
}

/// Everything the app stores, as one document.
class MotoData {
  const MotoData({
    this.bikes = const [],
    this.readings = const [],
    this.fuel = const [],
    this.services = const [],
    this.expenses = const [],
    this.papers = const [],
    this.selectedBikeId,
    this.currency = r'$',
    this.currencyCode = 'USD',
    this.lastBackup,
  });

  factory MotoData.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) => [
      for (final e in j[key] as List? ?? const []) f(e as Map<String, dynamic>),
    ];
    return MotoData(
      bikes: list('bikes', Bike.fromJson),
      readings: list('readings', OdometerReading.fromJson),
      fuel: list('fuel', FuelEntry.fromJson),
      services: list('services', ServiceEntry.fromJson),
      expenses: list('expenses', Expense.fromJson),
      papers: list('papers', Paper.fromJson),
      selectedBikeId: j['selectedBikeId'] as String?,
      currency: j['currency'] as String? ?? r'$',
      lastBackup: DateTime.tryParse(j['lastBackup'] as String? ?? ''),
      // Saves from before the picker have a symbol only.
      currencyCode: j.containsKey('currencyCode')
          ? j['currencyCode'] as String?
          : (j['currency'] == null ? 'USD' : null),
    );
  }

  final List<Bike> bikes;
  final List<OdometerReading> readings;
  final List<FuelEntry> fuel;
  final List<ServiceEntry> services;
  final List<Expense> expenses;
  final List<Paper> papers;
  final String? selectedBikeId;

  /// Symbol shown before money amounts.
  final String currency;

  /// ISO code of the picked currency; null for an older, symbol-only save.
  final String? currencyCode;

  /// When a backup file was last saved; null if never.
  final DateTime? lastBackup;

  Bike? get selectedBike {
    for (final b in bikes) {
      if (b.id == selectedBikeId) return b;
    }
    return bikes.isEmpty ? null : bikes.first;
  }

  MotoData copyWith({
    List<Bike>? bikes,
    List<OdometerReading>? readings,
    List<FuelEntry>? fuel,
    List<ServiceEntry>? services,
    List<Expense>? expenses,
    List<Paper>? papers,
    String? selectedBikeId,
    String? currency,
    String? currencyCode,
    DateTime? lastBackup,
  }) => MotoData(
    bikes: bikes ?? this.bikes,
    readings: readings ?? this.readings,
    fuel: fuel ?? this.fuel,
    services: services ?? this.services,
    expenses: expenses ?? this.expenses,
    papers: papers ?? this.papers,
    selectedBikeId: selectedBikeId ?? this.selectedBikeId,
    currency: currency ?? this.currency,
    currencyCode: currencyCode ?? this.currencyCode,
    lastBackup: lastBackup ?? this.lastBackup,
  );

  Map<String, dynamic> toJson() => {
    'bikes': [for (final b in bikes) b.toJson()],
    'readings': [for (final r in readings) r.toJson()],
    'fuel': [for (final f in fuel) f.toJson()],
    'services': [for (final s in services) s.toJson()],
    'expenses': [for (final e in expenses) e.toJson()],
    'papers': [for (final p in papers) p.toJson()],
    'selectedBikeId': selectedBikeId,
    'currency': currency,
    'currencyCode': currencyCode,
    'lastBackup': lastBackup?.toIso8601String(),
  };
}
