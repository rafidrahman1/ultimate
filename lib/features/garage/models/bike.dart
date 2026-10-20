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
