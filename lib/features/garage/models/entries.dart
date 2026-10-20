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
