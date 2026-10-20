import 'package:motohealth/features/garage/models/bike.dart';
import 'package:motohealth/features/garage/models/entries.dart';
import 'package:motohealth/features/garage/models/paper.dart';

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
