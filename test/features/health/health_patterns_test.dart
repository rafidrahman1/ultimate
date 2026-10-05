import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/health/health_patterns.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/vitals_models.dart';

DailySleepEntry _night(int day, int minutes) => DailySleepEntry(
  wakeDate: DateTime(2026, 9, day),
  session: SleepSummary(
    duration: Duration(minutes: minutes),
    startTime: DateTime(2026, 9, day - 1, 23),
    endTime: DateTime(2026, 9, day, 6),
  ),
);

DailyVitals _day(int day, {int? steps, int? rhr, double? hrv}) => DailyVitals(
  date: DateTime(2026, 9, day),
  steps: steps,
  restingHr: rhr,
  hrvMs: hrv,
);

VitalsSummary _vitals(
  List<DailyVitals> days, {
  List<WorkoutRecord> workouts = const [],
}) => VitalsSummary(
  periodStart: DateTime(2026, 9, 1),
  periodEnd: DateTime(2026, 9, 30),
  days: days,
  workouts: workouts,
  readMetrics: {VitalsMetric.steps},
);

void main() {
  // Days 1–8 follow short nights (5 h), days 9–16 follow full ones (8 h).
  final nights = [
    for (var d = 1; d <= 8; d++) _night(d, 300),
    for (var d = 9; d <= 16; d++) _night(d, 480),
  ];

  test('finds fewer steps after short nights', () {
    final vitals = _vitals([
      for (var d = 1; d <= 8; d++) _day(d, steps: 5000),
      for (var d = 9; d <= 16; d++) _day(d, steps: 8000),
    ]);
    final p = computeHealthPatterns(
      nights,
      vitals,
    ).firstWhere((p) => p.id == 'steps_after_sleep');
    expect(p.valueA, 5000);
    expect(p.valueB, 8000);
    expect(p.daysA, 8);
    expect(
      p.sentence,
      contains('5,000 steps after a night under 6 h (8 days)'),
    );
    expect(p.sentence, contains('8,000 steps after 7 h or more (8 days)'));
  });

  test('finds higher resting heart rate after short nights', () {
    final vitals = _vitals([
      for (var d = 1; d <= 8; d++) _day(d, rhr: 66),
      for (var d = 9; d <= 16; d++) _day(d, rhr: 58),
    ]);
    final p = computeHealthPatterns(
      nights,
      vitals,
    ).firstWhere((p) => p.id == 'rhr_after_sleep');
    expect(p.valueA, 66);
    expect(p.valueB, 58);
  });

  test('ignores differences too small to mean anything', () {
    final vitals = _vitals([
      for (var d = 1; d <= 8; d++) _day(d, steps: 8000, rhr: 60),
      for (var d = 9; d <= 16; d++) _day(d, steps: 8000, rhr: 61),
    ]);
    expect(computeHealthPatterns(nights, vitals), isEmpty);
  });

  test('needs enough days on each side', () {
    final vitals = _vitals([
      for (var d = 1; d <= 3; d++) _day(d, steps: 2000),
      for (var d = 9; d <= 16; d++) _day(d, steps: 9000),
    ]);
    expect(
      computeHealthPatterns(
        nights,
        vitals,
      ).where((p) => p.id == 'steps_after_sleep'),
      isEmpty,
    );
  });

  test('skips nights between 6 and 7 hours', () {
    final mixed = [
      for (var d = 1; d <= 8; d++) _night(d, 390),
      for (var d = 9; d <= 16; d++) _night(d, 480),
    ];
    final vitals = _vitals([
      for (var d = 1; d <= 16; d++) _day(d, steps: d <= 8 ? 1000 : 9000),
    ]);
    expect(
      computeHealthPatterns(
        mixed,
        vitals,
      ).where((p) => p.id == 'steps_after_sleep'),
      isEmpty,
    );
  });

  test('compares sleep after workout days with sleep after rest days', () {
    // Workouts on days 1–6; sleep the following nights is 90 min longer.
    final workouts = [
      for (var d = 1; d <= 6; d++)
        WorkoutRecord(
          type: 'RUNNING',
          start: DateTime(2026, 9, d, 7),
          end: DateTime(2026, 9, d, 7, 30),
        ),
    ];
    final n = [
      for (var d = 2; d <= 7; d++) _night(d, 480),
      for (var d = 8; d <= 13; d++) _night(d, 390),
    ];
    final vitals = _vitals([
      for (var d = 1; d <= 12; d++) _day(d, steps: 6000),
    ], workouts: workouts);
    final p = computeHealthPatterns(
      n,
      vitals,
    ).firstWhere((p) => p.id == 'sleep_after_workout');
    expect(p.valueA, 480);
    expect(p.valueB, 390);
    expect(p.sentence, contains('480 min the night after a workout'));
  });

  test('splits sleep by active versus quiet days at the median', () {
    final vitals = _vitals([
      for (var d = 1; d <= 12; d++) _day(d, steps: d <= 6 ? 3000 : 9000),
    ]);
    final n = [
      for (var d = 2; d <= 7; d++) _night(d, 360),
      for (var d = 8; d <= 13; d++) _night(d, 450),
    ];
    final p = computeHealthPatterns(
      n,
      vitals,
    ).firstWhere((p) => p.id == 'sleep_after_steps');
    expect(p.valueA, greaterThan(p.valueB));
  });

  test('returns nothing without vitals', () {
    expect(computeHealthPatterns(nights, null), isEmpty);
  });

  test('orders by strength', () {
    final vitals = _vitals([
      for (var d = 1; d <= 8; d++) _day(d, steps: 4000, rhr: 62),
      for (var d = 9; d <= 16; d++) _day(d, steps: 8000, rhr: 58),
    ]);
    final found = computeHealthPatterns(nights, vitals);
    final strengths = found.map((p) => p.strength).toList();
    expect(strengths, [...strengths]..sort((a, b) => b.compareTo(a)));
    expect(found.first.id, 'steps_after_sleep');
  });
}
