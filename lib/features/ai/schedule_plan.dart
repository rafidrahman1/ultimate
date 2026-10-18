import 'dart:convert';

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

/// One maintenance job the AI proposes, with its reasoning.
class ProposedTask {
  const ProposedTask({
    required this.name,
    required this.confidence,
    this.intervalKm,
    this.intervalDays,
    this.spec = '',
    this.why = '',
    this.source = '',
  });

  final String name;
  final double? intervalKm;
  final int? intervalDays;
  final String spec;
  final String why;
  final String source;
  final Confidence confidence;

  /// What gets stored on the job: the spec, then where the figure came from.
  String get note => [
    if (spec.isNotEmpty) spec,
    if (source.isNotEmpty) 'Source: $source',
  ].join('\n');
}

class SchedulePlan {
  const SchedulePlan({
    required this.identified,
    required this.confidence,
    required this.tasks,
    this.assumptions = const [],
    this.warnings = const [],
  });

  /// The machine the AI believes it is planning for, to be confirmed.
  final String identified;
  final Confidence confidence;
  final List<ProposedTask> tasks;
  final List<String> assumptions;
  final List<String> warnings;
}

const scheduleSystemPrompt = '''
You are a motorcycle service-schedule specialist. You produce the maintenance schedule the manufacturer publishes for one exact machine.

Rules, in order of importance:
1. Accuracy over completeness. Use the manufacturer's published owner's manual / service schedule for this exact make, model, year, variant and market. If you are not certain of a figure, give your best estimate for the class of bike but mark that job's confidence "low" and say so in "source". Never present a guess as "high".
2. Only include jobs that apply to this exact machine (no coolant on an air-cooled engine, no chain jobs on a belt or shaft drive, no valve shims on hydraulic tappets, no fuel filter if it is not serviceable).
3. Each job has "interval_km" and/or "interval_days". Give both when the manufacturer does ("every 6,000 km or 6 months"). Use null for one that does not apply. Do not invent a time limit for jobs the manufacturer only gives in km.
4. If conditions stated by the rider are severe (dust, stop-and-go traffic, heat, short trips, off-road), shorten the relevant intervals only where the manufacturer's own severe-use guidance supports it, and say so in "why".
5. Put practical specs in "spec": oil grade/standard and capacity, valve clearances, chain slack, tyre pressures, torque figures - only when you are sure of them.
6. If the bike is past the odometer of a one-off job (such as a first running-in service), leave that job out.
7. Reply with a single JSON object and nothing else - no markdown fences, no commentary.
''';

String buildSchedulePrompt(
  Bike bike,
  double odometerKm,
  List<String> existing,
) {
  final age = bike.year == null ? null : DateTime.now().year - bike.year!;
  final json = const JsonEncoder.withIndent('  ');
  final profile = json.convert({
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
  return '''
Build the full maintenance schedule for this motorcycle.

Bike:
$profile

Job names already in the app (reuse these exact names for the same job):
${existing.map((e) => '- $e').join('\n')}

Reply with JSON of exactly this shape:
{
  "identified": "the exact machine you are planning for, with engine, fuel system, cooling and final drive",
  "confidence": "high | medium | low",
  "assumptions": ["anything you assumed that the rider should confirm"],
  "warnings": ["model-specific cautions, known weak points or recalls you are sure about"],
  "tasks": [
    {
      "name": "short job name",
      "interval_km": number or null,
      "interval_days": number or null,
      "spec": "oil grade and quantity, clearance, torque ... or empty",
      "why": "one sentence",
      "source": "e.g. owner's manual service schedule, or general guidance for the class",
      "confidence": "high | medium | low"
    }
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

/// Reads the AI's answer. Jobs with impossible intervals or no name are
/// dropped; a duplicate name keeps its first entry. Throws [FormatException]
/// when there is no usable plan.
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

  double? km(Object? v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v');
    return n != null && n >= 100 && n <= 100000 ? n : null;
  }

  int? days(Object? v) {
    final n = v is num ? v.round() : int.tryParse('$v');
    return n != null && n >= 7 && n <= 3650 ? n : null;
  }

  List<String> strings(Object? v) => [
    for (final e in v as List? ?? const [])
      if ('$e'.trim().isNotEmpty) '$e'.trim(),
  ];

  final seen = <String>{};
  final tasks = <ProposedTask>[];
  for (final t in decoded['tasks'] as List? ?? const []) {
    if (t is! Map) continue;
    final name = '${t['name'] ?? ''}'.trim();
    final k = km(t['interval_km']);
    final d = days(t['interval_days']);
    if (name.isEmpty || (k == null && d == null)) continue;
    if (!seen.add(normalizeName(name))) continue;
    tasks.add(
      ProposedTask(
        name: name,
        intervalKm: k,
        intervalDays: d,
        spec: '${t['spec'] ?? ''}'.trim(),
        why: '${t['why'] ?? ''}'.trim(),
        source: '${t['source'] ?? ''}'.trim(),
        confidence: Confidence.parse(t['confidence']),
      ),
    );
  }
  if (tasks.isEmpty) {
    throw const FormatException('The plan had no usable jobs.');
  }
  return SchedulePlan(
    identified: '${decoded['identified'] ?? ''}'.trim(),
    confidence: Confidence.parse(decoded['confidence']),
    assumptions: strings(decoded['assumptions']),
    warnings: strings(decoded['warnings']),
    tasks: tasks,
  );
}

/// Lower-case letters and digits only, so "Engine Oil" matches "engine oil".
String normalizeName(String name) =>
    name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// The bike's job list after applying [chosen].
///
/// A chosen job with the same name as an existing one keeps that job's id, so
/// its service history stays attached, and takes the new intervals and note.
/// With [replace], existing jobs that were not chosen are dropped, except
/// those with logged service ([withHistory]), which are kept.
List<ServiceTask> applyPlan(
  Bike bike,
  List<ProposedTask> chosen, {
  required bool replace,
  Set<String> withHistory = const {},
}) {
  final byName = {for (final t in bike.tasks) normalizeName(t.name): t};
  final out = <ServiceTask>[];
  final used = <String>{};
  for (final p in chosen) {
    final old = byName[normalizeName(p.name)];
    final id = old?.id ?? 'ai-${newId()}-${out.length}';
    if (old != null) used.add(old.id);
    out.add(
      ServiceTask(
        id: id,
        name: old?.name ?? p.name,
        intervalKm: p.intervalKm,
        intervalDays: p.intervalDays,
        note: p.note,
      ),
    );
  }
  for (final t in bike.tasks) {
    if (used.contains(t.id)) continue;
    if (!replace || withHistory.contains(t.id)) {
      out.add(t);
    }
  }
  return out;
}

/// Ids of jobs that have at least one service logged against them.
Set<String> tasksWithHistory(MotoData data, Bike bike) => {
  for (final s in data.services)
    if (s.bikeId == bike.id) ...s.taskIds,
};

/// Details the plan can't be accurate without.
List<String> missingBikeDetails(Bike bike) => [
  if (bike.make.trim().isEmpty) 'make',
  if (bike.model.trim().isEmpty) 'model',
  if (bike.year == null) 'year',
];
