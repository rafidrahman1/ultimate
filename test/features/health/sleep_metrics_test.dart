import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_metrics.dart';

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
}
