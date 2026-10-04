import 'package:intl/intl.dart';

import 'package:personal/features/health/health_patterns.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_stage_stats.dart';
import 'package:personal/features/health/vitals_models.dart';

final _number = NumberFormat.decimalPattern();

String _duration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
}

String _pct(double share) => '${(share * 100).round()}%';

/// " (previous period 6,900)" or "" when there is nothing to compare.
String _versus(Object? previous) =>
    previous == null ? '' : ' (previous period $previous)';

/// Sleep stages: where the night's sleep went. Empty when too few nights
/// recorded stages to say anything.
String buildSleepStagesText(
  List<DailySleepEntry> nights, {
  List<DailySleepEntry>? previousNights,
}) {
  final stats = computeSleepStageStats(nights);
  if (stats == null) return '';
  final previous = previousNights == null
      ? null
      : computeSleepStageStats(previousNights);

  final buffer = StringBuffer('Sleep Stages (${stats.nights} nights with stages):')
    ..writeln()
    ..writeln(
      '- Deep: ${_duration(stats.avgDeep)} avg (${_pct(stats.deepShare)} of sleep)'
      '${_versus(previous == null ? null : _pct(previous.deepShare))}',
    )
    ..writeln(
      '- REM: ${_duration(stats.avgRem)} avg (${_pct(stats.remShare)} of sleep)'
      '${_versus(previous == null ? null : _pct(previous.remShare))}',
    )
    ..writeln(
      '- Light: ${_duration(stats.avgLight)} avg (${_pct(stats.lightShare)} of sleep)',
    )
    ..writeln(
      '- Awake during the night: ${_duration(stats.avgAwake)} avg, '
      '${stats.avgAwakeEpisodes.toStringAsFixed(1)} wake-ups per night',
    );
  final efficiency = stats.avgEfficiency;
  if (efficiency != null) {
    buffer.writeln(
      '- Sleep efficiency: ${_pct(efficiency)}'
      '${_versus(previous?.avgEfficiency == null ? null : _pct(previous!.avgEfficiency!))}',
    );
  }
  return buffer.toString().trimRight();
}

/// Activity, workouts, heart and body metrics, plus patterns across them and
/// sleep. Everything is aggregated: no individual readings are included.
String buildVitalsPromptText(
  VitalsSummary vitals, {
  VitalsSummary? previous,
  List<DailySleepEntry> nights = const [],
}) {
  if (!vitals.hasData) return '';
  final sections = <String>[];

  final activity = _activity(vitals, previous);
  if (activity.isNotEmpty) sections.add(activity);

  final workouts = _workouts(vitals, previous);
  if (workouts.isNotEmpty) sections.add(workouts);

  final heart = _heart(vitals, previous);
  if (heart.isNotEmpty) sections.add(heart);

  final body = _body(vitals);
  if (body.isNotEmpty) sections.add(body);

  final patterns = computeHealthPatterns(nights, vitals);
  if (patterns.isNotEmpty) {
    sections.add(
      [
        'Patterns in this period (observations, not proven causes):',
        for (final p in patterns.take(4)) '- ${p.sentence}',
      ].join('\n'),
    );
  }

  return sections.join('\n\n');
}

String _activity(VitalsSummary v, VitalsSummary? previous) {
  final average = v.averageSteps;
  if (average == null) return '';
  final lines = <String>['Activity:'];

  final prevAverage = previous?.averageSteps;
  lines.add(
    '- Steps: ${_number.format(average.round())}/day on average over '
    '${v.stepDays.length} tracked days'
    '${_versus(prevAverage == null ? null : _number.format(prevAverage.round()))}',
  );
  final best = v.bestStepDay!;
  lines.add(
    '- Best day: ${_number.format(best.steps)} steps on '
    '${DateFormat('d MMM').format(best.date)}; '
    '${v.daysWithSteps(10000)} days at 10,000+ and '
    '${v.stepDays.where((d) => d.steps! < 3000).length} days under 3,000',
  );
  final km = v.totalDistanceKm;
  if (km != null) {
    lines.add('- Distance on foot and bike: ${km.toStringAsFixed(1)} km');
  }
  final kcal = v.totalActiveKcal;
  if (kcal != null) {
    lines.add('- Active energy: ${_number.format(kcal.round())} kcal');
  }
  final missing = v.days.length - v.stepDays.length;
  if (missing > 0) lines.add('- $missing days had no step data');
  return lines.join('\n');
}

String _workouts(VitalsSummary v, VitalsSummary? previous) {
  if (v.workouts.isEmpty) {
    // Only worth saying if workouts are actually connected.
    return v.readMetrics.contains(VitalsMetric.workouts)
        ? 'Workouts:\n- None recorded this period'
              '${previous != null && previous.workouts.isNotEmpty ? ' (previous period ${previous.workouts.length})' : ''}'
        : '';
  }
  final lines = <String>[
    'Workouts:',
    '- ${v.workouts.length} sessions on ${v.workoutDays} days, '
        '${_duration(v.totalWorkoutTime)} total'
        '${previous == null ? '' : ' (previous period ${previous.workouts.length} sessions, ${_duration(previous.totalWorkoutTime)})'}',
  ];
  for (final type in v.workoutsByType.take(4)) {
    final extras = <String>[
      if (type.distanceMeters != null)
        '${(type.distanceMeters! / 1000).toStringAsFixed(1)} km',
      if (type.kcal != null) '${_number.format(type.kcal!.round())} kcal',
    ];
    lines.add(
      '  - ${type.label}: ${type.count}×, ${_duration(type.duration)}'
      '${extras.isEmpty ? '' : ', ${extras.join(', ')}'}',
    );
  }
  return lines.join('\n');
}

String _heart(VitalsSummary v, VitalsSummary? previous) {
  final lines = <String>[];
  String bpm(double? x) => x == null ? '' : x.toStringAsFixed(0);

  final resting = v.averageRestingHr;
  if (resting != null) {
    lines.add(
      '- Resting heart rate: ${bpm(resting)} bpm average'
      '${_versus(previous?.averageRestingHr == null ? null : '${bpm(previous!.averageRestingHr)} bpm')}',
    );
  }
  final hrv = v.averageHrv;
  if (hrv != null) {
    lines.add(
      '- Heart rate variability: ${bpm(hrv)} ms average (compare only with your own history)'
      '${_versus(previous?.averageHrv == null ? null : '${bpm(previous!.averageHrv)} ms')}',
    );
  }
  final average = v.averageHr;
  if (average != null) {
    final low = v.averageMinHr;
    final peak = v.peakHr;
    lines.add(
      '- Heart rate across the day: ${bpm(average)} bpm average'
      '${low == null ? '' : ', daily low ${bpm(low)} bpm'}'
      '${peak == null ? '' : ', peak $peak bpm'}',
    );
  }
  final spo2 = v.averageSpo2;
  if (spo2 != null) {
    lines.add('- Blood oxygen: ${spo2.toStringAsFixed(1)}% average');
  }
  return lines.isEmpty ? '' : ['Heart:', ...lines].join('\n');
}

String _body(VitalsSummary v) {
  final latest = v.latestWeight;
  if (latest == null) return '';
  final change = v.weightChangeKg;
  final lines = <String>[
    'Body:',
    '- Latest weight: ${latest.kg.toStringAsFixed(1)} kg '
        '(${DateFormat('d MMM').format(latest.time)})'
        '${change == null ? '' : ', ${change >= 0 ? '+' : '−'}${change.abs().toStringAsFixed(1)} kg since '
                  '${DateFormat('d MMM').format(v.weights.first.time)}'}',
  ];
  return lines.join('\n');
}
