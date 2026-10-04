import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/vitals_models.dart';
import 'package:personal/features/health/vitals_prompt_builder.dart';

SleepStages _stages() => const SleepStages(
  deep: Duration(minutes: 70),
  light: Duration(minutes: 230),
  rem: Duration(minutes: 100),
  awake: Duration(minutes: 20),
  awakeEpisodes: 2,
);

DailySleepEntry _night(int day, int minutes, {bool stages = true}) =>
    DailySleepEntry(
      wakeDate: DateTime(2026, 9, day),
      session: SleepSummary(
        duration: Duration(minutes: minutes),
        startTime: DateTime(2026, 9, day - 1, 23),
        endTime: DateTime(2026, 9, day, 6),
        stages: stages ? _stages() : null,
      ),
    );

VitalsSummary _month({
  int steps = 7000,
  int rhr = 60,
  List<WorkoutRecord>? workouts,
  List<WeightReading> weights = const [],
  Set<VitalsMetric>? read,
}) => VitalsSummary(
  periodStart: DateTime(2026, 9, 1),
  periodEnd: DateTime(2026, 9, 30),
  days: [
    for (var d = 1; d <= 30; d++)
      DailyVitals(
        date: DateTime(2026, 9, d),
        steps: d <= 25 ? steps + (d == 12 ? 7000 : 0) : null,
        restingHr: rhr,
        avgHr: 74,
        minHr: 52,
        maxHr: d == 9 ? 168 : 140,
        hrvMs: 48,
        spo2Avg: 96.2,
        distanceMeters: 4000,
        activeKcal: 300,
      ),
  ],
  workouts:
      workouts ??
      [
        for (var d = 2; d <= 20; d += 6)
          WorkoutRecord(
            type: 'RUNNING',
            start: DateTime(2026, 9, d, 7),
            end: DateTime(2026, 9, d, 7, 40),
            kcal: 320,
            distanceMeters: 6000,
          ),
      ],
  weights: weights,
  readMetrics: read ?? {for (final m in VitalsMetric.values) m},
);

void main() {
  test('writes activity, workouts and heart sections', () {
    final text = buildVitalsPromptText(_month());
    expect(text, contains('Activity:'));
    expect(text, contains('Steps: 7,280/day on average over 25 tracked days'));
    expect(text, contains('Best day: 14,000 steps on 12 Sep'));
    expect(text, contains('1 days at 10,000+'));
    expect(text, contains('5 days had no step data'));
    expect(text, contains('Workouts:'));
    expect(text, contains('4 sessions on 4 days, 2h 40m total'));
    expect(text, contains('Running: 4×, 2h 40m, 24.0 km, 1,280 kcal'));
    expect(text, contains('Heart:'));
    expect(text, contains('Resting heart rate: 60 bpm average'));
    expect(text, contains('Heart rate variability: 48 ms'));
    expect(text, contains('peak 168 bpm'));
    expect(text, contains('Blood oxygen: 96.2% average'));
  });

  test('compares with the previous period', () {
    final text = buildVitalsPromptText(
      _month(steps: 8000, rhr: 58),
      previous: _month(steps: 6000, rhr: 63),
    );
    expect(text, contains('(previous period 6,280)'));
    expect(text, contains('(previous period 63 bpm)'));
    expect(text, contains('(previous period 4 sessions, 2h 40m)'));
  });

  test('describes weight change over the period', () {
    final text = buildVitalsPromptText(
      _month(
        weights: [
          WeightReading(time: DateTime(2026, 8, 20), kg: 79.0),
          WeightReading(time: DateTime(2026, 9, 25), kg: 78.4),
        ],
      ),
    );
    expect(
      text,
      contains('Latest weight: 78.4 kg (25 Sep), −0.6 kg since 20 Aug'),
    );
  });

  test('says so when workouts are connected but none happened', () {
    final text = buildVitalsPromptText(_month(workouts: const []));
    expect(text, contains('None recorded this period'));
  });

  test('stays quiet about workouts that were never connected', () {
    final text = buildVitalsPromptText(
      _month(workouts: const [], read: {VitalsMetric.steps}),
    );
    expect(text, isNot(contains('Workouts:')));
  });

  test('is empty with no data', () {
    final empty = VitalsSummary.empty(
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 30),
    );
    expect(buildVitalsPromptText(empty), '');
  });

  test('includes only aggregates, never raw timestamps or per-day lists', () {
    final text = buildVitalsPromptText(_month());
    expect(text, isNot(contains('T07:')));
    expect(RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(text), isFalse);
    expect(text.split('\n').length, lessThan(30));
  });

  group('sleep stages', () {
    final nights = [for (var d = 2; d <= 8; d++) _night(d, 400)];

    test('reports share and efficiency', () {
      final text = buildSleepStagesText(nights);
      expect(text, contains('Sleep Stages (7 nights with stages):'));
      expect(text, contains('Deep: 1h 10m avg (18% of sleep)'));
      expect(text, contains('REM: 1h 40m avg (25% of sleep)'));
      expect(text, contains('2.0 wake-ups per night'));
      expect(text, contains('Sleep efficiency: 95%'));
    });

    test('compares with the previous period', () {
      final text = buildSleepStagesText(nights, previousNights: nights);
      expect(text, contains('(previous period 18%)'));
    });

    test('is empty without enough staged nights', () {
      expect(
        buildSleepStagesText([_night(2, 400, stages: false), _night(3, 400)]),
        '',
      );
    });
  });

  test('the monthly summary composes sleep, stages and vitals', () {
    final summary = MonthlyHealthSummary(
      periodStart: DateTime(2026, 9, 1),
      periodEnd: DateTime(2026, 9, 30),
      dayCount: 30,
      dailySleep: [for (var d = 2; d <= 12; d++) _night(d, 420)],
      vitals: _month(),
    );
    final text = summary.toAnalysisPromptText();
    expect(text, startsWith('Sleep Summary'));
    expect(
      text.indexOf('Sleep Stages'),
      greaterThan(text.indexOf('Sleep Summary')),
    );
    expect(
      text.indexOf('Activity:'),
      greaterThan(text.indexOf('Sleep Stages')),
    );
  });

  test('vitals alone still produce a health block', () {
    final summary = MonthlyHealthSummary(
      periodStart: DateTime(2026, 9, 1),
      periodEnd: DateTime(2026, 9, 30),
      dayCount: 30,
      dailySleep: const [],
      vitals: _month(),
    );
    expect(summary.toAnalysisPromptText(), startsWith('Activity:'));
  });

  test('patterns reach the prompt when the data supports them', () {
    final nights = [
      for (var d = 1; d <= 8; d++) _night(d, 300),
      for (var d = 9; d <= 16; d++) _night(d, 480),
    ];
    final vitals = VitalsSummary(
      periodStart: DateTime(2026, 9, 1),
      periodEnd: DateTime(2026, 9, 30),
      days: [
        for (var d = 1; d <= 16; d++)
          DailyVitals(date: DateTime(2026, 9, d), steps: d <= 8 ? 4000 : 8000),
      ],
      readMetrics: {VitalsMetric.steps},
    );
    final text = buildVitalsPromptText(vitals, nights: nights);
    expect(
      text,
      contains('Patterns in this period (observations, not proven causes):'),
    );
    expect(
      text,
      contains(
        'Steps: 4,000 steps after a night under 6 h (8 days) vs 8,000 steps after 7 h or more (8 days)',
      ),
    );
  });
}
