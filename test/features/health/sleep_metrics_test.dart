import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_metrics.dart';
import 'package:personal/features/results/derived_metric_validation.dart';

DailySleepEntry _night(int day, int hours, int minutes) {
  return DailySleepEntry(
    wakeDate: DateTime(2026, 5, day),
    session: SleepSummary(
      duration: Duration(hours: hours, minutes: minutes),
      startTime: DateTime(2026, 5, day - 1, 23, 0),
      endTime: DateTime(2026, 5, day, 7, 0),
    ),
  );
}

void main() {
  test('computeSleepDebt sums deficits below 7h target', () {
    final debt = computeSleepDebt([
      _night(1, 6, 30),
      _night(2, 5, 13),
      _night(3, 8, 0),
    ]);

    expect(debt.nightsBelowTarget, 2);
    expect(debt.estimatedDebt, const Duration(hours: 2, minutes: 17));
  });

  test('buildSleepDebtText formats target and debt duration', () {
    final text = buildSleepDebtText([
      for (var day = 1; day <= 15; day++) _night(day, 6, 13),
    ]);

    expect(text, contains('Target: 7h'));
    expect(text, contains('Nights below target: 15'));
    expect(text, contains('Estimated sleep debt: 11h 45m'));
  });

  test('circular std dev treats midnight crossover bedtimes as close', () {
    final bedtimes = [
      DateTime(2026, 5, 1, 23, 50),
      DateTime(2026, 5, 2, 0, 10),
    ];
    final stdDev = circularStdDevClockMinutes(
      bedtimes.map((time) => time.hour * 60 + time.minute),
    );

    expect(stdDev, lessThan(30));
    expect(stdDev, greaterThan(0));
  });

  test('bedtime std dev stays reasonable across late night range', () {
    final nights = [
      DailySleepEntry(
        wakeDate: DateTime(2026, 5, 2),
        session: SleepSummary(
          duration: const Duration(hours: 7),
          startTime: DateTime(2026, 5, 1, 22, 7),
          endTime: DateTime(2026, 5, 2, 7, 0),
        ),
      ),
      DailySleepEntry(
        wakeDate: DateTime(2026, 5, 3),
        session: SleepSummary(
          duration: const Duration(hours: 7),
          startTime: DateTime(2026, 5, 3, 3, 6),
          endTime: DateTime(2026, 5, 3, 10, 0),
        ),
      ),
    ];

    final consistency = computeSleepConsistency(nights);
    expect(consistency, isNotNull);
    expect(consistency!.bedtimeStdDevMinutes, lessThan(360));
    expect(consistency.bedtimeStdDevMinutes, greaterThan(0));
  });
}
