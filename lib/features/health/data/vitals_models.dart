import 'package:personal/core/period_range.dart';

/// Health Connect data families beyond sleep. Each is a separate permission,
/// so the user can allow some and not others.
enum VitalsMetric {
  steps('Steps'),
  heartRate('Heart rate'),
  restingHeartRate('Resting heart rate'),
  hrv('Heart rate variability'),
  workouts('Workouts'),
  activeEnergy('Active calories'),
  distance('Distance'),
  weight('Weight'),
  oxygen('Blood oxygen');

  const VitalsMetric(this.label);

  final String label;

  static VitalsMetric? byName(String? name) {
    for (final metric in values) {
      if (metric.name == name) return metric;
    }
    return null;
  }
}

/// One local calendar day of non-sleep health data. Every field is null when
/// that metric has no data for the day, so "0 steps" and "not recorded" stay
/// distinct.
class DailyVitals {
  const DailyVitals({
    required this.date,
    this.steps,
    this.activeKcal,
    this.distanceMeters,
    this.restingHr,
    this.minHr,
    this.avgHr,
    this.maxHr,
    this.hrvMs,
    this.spo2Avg,
    this.spo2Min,
  });

  /// Local midnight.
  final DateTime date;
  final int? steps;
  final double? activeKcal;
  final double? distanceMeters;

  /// Recorded resting heart rate (from Health Connect, not estimated).
  final int? restingHr;
  final int? minHr;
  final int? avgHr;
  final int? maxHr;

  /// Heart rate variability (RMSSD, ms). Only comparable with your own history.
  final double? hrvMs;
  final double? spo2Avg;
  final double? spo2Min;

  bool get hasAny =>
      steps != null ||
      activeKcal != null ||
      distanceMeters != null ||
      restingHr != null ||
      avgHr != null ||
      hrvMs != null ||
      spo2Avg != null;

  Map<String, dynamic> toJson() => {
    'd': date.toIso8601String(),
    'steps': steps,
    'kcal': activeKcal,
    'dist': distanceMeters,
    'rhr': restingHr,
    'minHr': minHr,
    'avgHr': avgHr,
    'maxHr': maxHr,
    'hrv': hrvMs,
    'spo2': spo2Avg,
    'spo2Min': spo2Min,
  };

  factory DailyVitals.fromJson(Map<String, dynamic> json) => DailyVitals(
    date: DateTime.parse(json['d'] as String),
    steps: (json['steps'] as num?)?.toInt(),
    activeKcal: (json['kcal'] as num?)?.toDouble(),
    distanceMeters: (json['dist'] as num?)?.toDouble(),
    restingHr: (json['rhr'] as num?)?.toInt(),
    minHr: (json['minHr'] as num?)?.toInt(),
    avgHr: (json['avgHr'] as num?)?.toInt(),
    maxHr: (json['maxHr'] as num?)?.toInt(),
    hrvMs: (json['hrv'] as num?)?.toDouble(),
    spo2Avg: (json['spo2'] as num?)?.toDouble(),
    spo2Min: (json['spo2Min'] as num?)?.toDouble(),
  );
}

/// An exercise session.
class WorkoutRecord {
  const WorkoutRecord({
    required this.type,
    required this.start,
    required this.end,
    this.kcal,
    this.distanceMeters,
    this.steps,
  });

  /// Upper-case type from Health Connect, e.g. `RUNNING`, `BIKING`.
  final String type;
  final DateTime start;
  final DateTime end;
  final double? kcal;
  final double? distanceMeters;
  final int? steps;

  Duration get duration => end.difference(start);

  /// `STRENGTH_TRAINING` → `Strength training`.
  String get label {
    final words = type.toLowerCase().split('_').where((w) => w.isNotEmpty);
    if (words.isEmpty) return 'Workout';
    final text = words.join(' ');
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'kcal': kcal,
    'dist': distanceMeters,
    'steps': steps,
  };

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) => WorkoutRecord(
    type: json['type'] as String? ?? 'OTHER',
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    kcal: (json['kcal'] as num?)?.toDouble(),
    distanceMeters: (json['dist'] as num?)?.toDouble(),
    steps: (json['steps'] as num?)?.toInt(),
  );
}

class WeightReading {
  const WeightReading({required this.time, required this.kg});

  final DateTime time;
  final double kg;

  Map<String, dynamic> toJson() => {'t': time.toIso8601String(), 'kg': kg};

  factory WeightReading.fromJson(Map<String, dynamic> json) => WeightReading(
    time: DateTime.parse(json['t'] as String),
    kg: (json['kg'] as num).toDouble(),
  );
}

/// Aggregate of a workout type over the period.
class WorkoutTypeTotal {
  const WorkoutTypeTotal({
    required this.label,
    required this.count,
    required this.duration,
    this.kcal,
    this.distanceMeters,
  });

  final String label;
  final int count;
  final Duration duration;
  final double? kcal;
  final double? distanceMeters;
}

/// All non-sleep health data for one analysis period.
class VitalsSummary {
  const VitalsSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.days,
    this.workouts = const [],
    this.weights = const [],
    this.readMetrics = const {},
    this.sources = const {},
  });

  static VitalsSummary empty(DateTime start, DateTime end) =>
      VitalsSummary(periodStart: start, periodEnd: end, days: const []);

  final DateTime periodStart;
  final DateTime periodEnd;

  /// One entry per day of the period (oldest first), including days with no
  /// data, so charts and averages see the true number of days.
  final List<DailyVitals> days;
  final List<WorkoutRecord> workouts;

  /// Weight readings in the period plus the latest one before it, oldest first.
  final List<WeightReading> weights;

  /// Metrics the user granted and that were read, whether or not they had data.
  final Set<VitalsMetric> readMetrics;

  /// Which apps wrote each metric, e.g. `steps → {Samsung Health}`.
  final Map<VitalsMetric, Set<String>> sources;

  String get periodRangeLabel => formatPeriodRange(periodStart, periodEnd);

  bool get hasData =>
      days.any((d) => d.hasAny) || workouts.isNotEmpty || weights.isNotEmpty;

  /// True once the user has granted at least one of these metrics.
  bool get isConnected => readMetrics.isNotEmpty;

  // ── Steps ──────────────────────────────────────────────────────────────
  List<DailyVitals> get stepDays => days.where((d) => d.steps != null).toList();

  int get totalSteps => stepDays.fold(0, (sum, d) => sum + d.steps!);

  /// Mean over days that have a step count.
  double? get averageSteps =>
      stepDays.isEmpty ? null : totalSteps / stepDays.length;

  DailyVitals? get bestStepDay => stepDays.isEmpty
      ? null
      : stepDays.reduce((a, b) => a.steps! >= b.steps! ? a : b);

  /// Days at or above [threshold] steps.
  int daysWithSteps(int threshold) =>
      stepDays.where((d) => d.steps! >= threshold).length;

  double? get totalDistanceKm {
    final days = this.days.where((d) => d.distanceMeters != null);
    if (days.isEmpty) return null;
    return days.fold<double>(0, (sum, d) => sum + d.distanceMeters!) / 1000;
  }

  double? get totalActiveKcal {
    final days = this.days.where((d) => d.activeKcal != null);
    if (days.isEmpty) return null;
    return days.fold<double>(0, (sum, d) => sum + d.activeKcal!);
  }

  // ── Heart ──────────────────────────────────────────────────────────────
  double? _mean(Iterable<num?> values) {
    final present = values.whereType<num>().toList();
    if (present.isEmpty) return null;
    return present.fold<double>(0, (sum, v) => sum + v) / present.length;
  }

  double? get averageRestingHr => _mean(days.map((d) => d.restingHr));
  double? get averageMinHr => _mean(days.map((d) => d.minHr));
  double? get averageHr => _mean(days.map((d) => d.avgHr));
  double? get averageHrv => _mean(days.map((d) => d.hrvMs));
  double? get averageSpo2 => _mean(days.map((d) => d.spo2Avg));

  int? get peakHr {
    final peaks = days.map((d) => d.maxHr).whereType<int>();
    return peaks.isEmpty ? null : peaks.reduce((a, b) => a > b ? a : b);
  }

  // ── Workouts ───────────────────────────────────────────────────────────
  Duration get totalWorkoutTime =>
      workouts.fold(Duration.zero, (sum, w) => sum + w.duration);

  /// Days with at least one workout.
  int get workoutDays => workouts
      .map((w) => '${w.start.year}-${w.start.month}-${w.start.day}')
      .toSet()
      .length;

  /// Per-type totals, most time first.
  List<WorkoutTypeTotal> get workoutsByType {
    final grouped = <String, List<WorkoutRecord>>{};
    for (final w in workouts) {
      grouped.putIfAbsent(w.label, () => []).add(w);
    }
    final totals = [
      for (final entry in grouped.entries)
        WorkoutTypeTotal(
          label: entry.key,
          count: entry.value.length,
          duration: entry.value.fold(
            Duration.zero,
            (sum, w) => sum + w.duration,
          ),
          kcal: _sumOrNull(entry.value.map((w) => w.kcal)),
          distanceMeters: _sumOrNull(entry.value.map((w) => w.distanceMeters)),
        ),
    ]..sort((a, b) => b.duration.compareTo(a.duration));
    return totals;
  }

  // ── Weight ─────────────────────────────────────────────────────────────
  WeightReading? get latestWeight => weights.isEmpty ? null : weights.last;

  /// Change from the last reading before the period (or the first in it) to
  /// the latest one. Null with fewer than two readings.
  double? get weightChangeKg {
    if (weights.length < 2) return null;
    return weights.last.kg - weights.first.kg;
  }

  Map<String, dynamic> toJson() => {
    'start': periodStart.toIso8601String(),
    'end': periodEnd.toIso8601String(),
    'days': days.map((d) => d.toJson()).toList(),
    'workouts': workouts.map((w) => w.toJson()).toList(),
    'weights': weights.map((w) => w.toJson()).toList(),
    'read': [for (final m in readMetrics) m.name],
    'sources': {
      for (final entry in sources.entries) entry.key.name: entry.value.toList(),
    },
  };

  factory VitalsSummary.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      if (raw is! List) return <T>[];
      return [
        for (final item in raw)
          if (item is Map) parse(item.cast<String, dynamic>()),
      ];
    }

    final sources = <VitalsMetric, Set<String>>{};
    final rawSources = json['sources'];
    if (rawSources is Map) {
      rawSources.forEach((key, value) {
        final metric = VitalsMetric.byName(key.toString());
        if (metric != null && value is List) {
          sources[metric] = {for (final v in value) v.toString()};
        }
      });
    }

    return VitalsSummary(
      periodStart: DateTime.parse(json['start'] as String),
      periodEnd: DateTime.parse(json['end'] as String),
      days: list('days', DailyVitals.fromJson),
      workouts: list('workouts', WorkoutRecord.fromJson),
      weights: list('weights', WeightReading.fromJson),
      readMetrics: {
        for (final name in (json['read'] as List?) ?? const [])
          ?VitalsMetric.byName(name.toString()),
      },
      sources: sources,
    );
  }
}

double? _sumOrNull(Iterable<double?> values) {
  final present = values.whereType<double>().toList();
  if (present.isEmpty) return null;
  return present.fold<double>(0, (sum, v) => sum + v);
}
