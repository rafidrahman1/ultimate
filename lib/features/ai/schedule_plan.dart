import 'dart:convert';

import 'package:motohealth/features/garage/maintenance_catalog.dart';
import 'package:motohealth/features/garage/moto_models.dart';

enum Confidence {
  high('High'),
  medium('Medium'),
  low('Low');

  const Confidence(this.label);
  final String label;

  static Confidence parse(Object? v) => switch ('$v'.toLowerCase().trim()) {
    'high' => Confidence.high,
    'medium' => Confidence.medium,
    _ => Confidence.low,
  };
}

/// A catalog job the AI says belongs on this bike, and why.
class Pick {
  const Pick({
    required this.item,
    required this.reason,
    required this.confidence,
  });

  final CatalogItem item;
  final String reason;
  final Confidence confidence;
}

/// The AI's choice of catalog jobs for one bike. It never invents jobs or
/// intervals: [picks] only holds jobs from [maintenanceCatalog].
class SchedulePlan {
  const SchedulePlan({
    required this.identified,
    required this.confidence,
    required this.picks,
    this.assumptions = const [],
    this.warnings = const [],
  });

  /// The machine the AI believes it is choosing for, to be confirmed.
  final String identified;
  final Confidence confidence;
  final List<Pick> picks;
  final List<String> assumptions;
  final List<String> warnings;

  Set<String> get pickedIds => {for (final p in picks) p.item.id};
}

const scheduleSystemPrompt = '''
You decide which maintenance jobs apply to one exact motorcycle. You are given a fixed catalog of jobs; you choose from it. You do not write new jobs and you do not change intervals.

Rules, in order of importance:
1. Work out what the machine is from make, model, year, variant and engine size: engine type, cooling (air, oil or liquid), fuel system (carburettor or injection), final drive (chain, belt, shaft or CVT scooter), clutch (manual cable, hydraulic, automatic), brakes (disc, drum, ABS), wheels (cast or spoked).
2. Select a catalog job only if it applies to that machine, following what the manufacturer's service schedule for this model lists. Leave out jobs that cannot apply (no coolant on an air-cooled engine, no chain jobs on a belt, shaft or CVT drive, no spark plug on an electric bike, no spokes on cast wheels).
3. If you are not sure whether a job applies, include it only when it is common for this type of bike, and mark that pick confidence "low".
4. Use the ids exactly as given. Never output an id that is not in the catalog.
5. Give one short reason per pick that refers to this bike (for example "air-cooled single, so no coolant" is a reason to leave out; "chain drive" is a reason to keep).
6. Reply with a single JSON object and nothing else - no markdown fences, no commentary.
''';

String buildSchedulePrompt(Bike bike, double odometerKm) {
  final age = bike.year == null ? null : DateTime.now().year - bike.year!;
  final profile = const JsonEncoder.withIndent('  ').convert({
    'make': bike.make,
    'model': bike.model,
    'year': bike.year,
    'variant_or_notes': bike.variant,
    'engine_cc': bike.engineCc?.round(),
    'current_odometer_km': odometerKm.round(),
    'age_years': age,
    'usage': bike.usage,
    'riding_conditions': bike.conditions,
  });
  final catalog = [
    for (final i in maintenanceCatalog)
      '${i.id} | ${i.name} | applies to: ${i.hint}',
  ].join('\n');
  return '''
Choose the maintenance jobs that belong on this motorcycle.

Bike:
$profile

Catalog (id | name | applies to):
$catalog

Reply with JSON of exactly this shape:
{
  "identified": "the exact machine you chose for, with engine, cooling, fuel system and final drive",
  "confidence": "high | medium | low",
  "assumptions": ["anything you assumed that the rider should confirm"],
  "warnings": ["model-specific cautions you are sure about"],
  "selected": [
    {"id": "catalog id", "reason": "one short sentence about this bike", "confidence": "high | medium | low"}
  ]
}
''';
}

String? _extractJson(String text) {
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  return text.substring(start, end + 1);
}

/// Reads the AI's answer. Ids that are not in the catalog are dropped, and a
/// repeated id keeps its first entry. Picks come back in catalog order. Throws
/// [FormatException] when nothing usable is left.
SchedulePlan parseSchedulePlan(String text) {
  final raw = _extractJson(text);
  if (raw == null) throw const FormatException('No JSON in the answer.');
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    throw const FormatException('The answer was not valid JSON.');
  }
  if (decoded is! Map) throw const FormatException('Unexpected answer shape.');

  List<String> strings(Object? v) => [
    for (final e in v as List? ?? const [])
      if ('$e'.trim().isNotEmpty) '$e'.trim(),
  ];

  final found = <String, Pick>{};
  for (final s in decoded['selected'] as List? ?? const []) {
    final id = s is Map ? '${s['id'] ?? ''}'.trim() : '$s'.trim();
    final item = catalogItem(id);
    if (item == null || found.containsKey(id)) continue;
    found[id] = Pick(
      item: item,
      reason: s is Map ? '${s['reason'] ?? ''}'.trim() : '',
      confidence: s is Map ? Confidence.parse(s['confidence']) : Confidence.low,
    );
  }
  if (found.isEmpty) {
    throw const FormatException('The answer chose no known jobs.');
  }
  return SchedulePlan(
    identified: '${decoded['identified'] ?? ''}'.trim(),
    confidence: Confidence.parse(decoded['confidence']),
    assumptions: strings(decoded['assumptions']),
    warnings: strings(decoded['warnings']),
    picks: [
      for (final item in maintenanceCatalog)
        if (found[item.id] != null) found[item.id]!,
    ],
  );
}

/// The bike's job list once [chosenIds] are on it.
///
/// A chosen job the bike already has is left as it is, so the rider's edited
/// intervals and service history stay. A chosen job it lacks is added with
/// the catalog interval. With [replace], catalog jobs that were not chosen
/// are removed, except those with logged service ([withHistory]). Jobs the
/// rider made themselves (ids outside the catalog) are always kept.
List<ServiceTask> applySelection(
  Bike bike,
  Set<String> chosenIds, {
  required bool replace,
  Set<String> withHistory = const {},
}) {
  final have = {for (final t in bike.tasks) t.id};
  final out = <ServiceTask>[];
  for (final t in bike.tasks) {
    final inCatalog = catalogItem(t.id) != null;
    final keep =
        chosenIds.contains(t.id) ||
        !inCatalog ||
        !replace ||
        withHistory.contains(t.id);
    if (keep) out.add(t);
  }
  for (final item in maintenanceCatalog) {
    if (chosenIds.contains(item.id) && !have.contains(item.id)) {
      out.add(item.toTask());
    }
  }
  return out;
}

/// Ids of jobs that have at least one service logged against them.
Set<String> tasksWithHistory(MotoData data, Bike bike) => {
  for (final s in data.services)
    if (s.bikeId == bike.id) ...s.taskIds,
};

/// Details the choice can't be accurate without.
List<String> missingBikeDetails(Bike bike) => [
  if (bike.make.trim().isEmpty) 'make',
  if (bike.model.trim().isEmpty) 'model',
  if (bike.year == null) 'year',
];
