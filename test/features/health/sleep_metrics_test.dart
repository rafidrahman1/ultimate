import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_metrics.dart';

DailySleepEntry _night(int day, int minutes) {
  final end = DateTime(2026, 9, day, 7);
  return DailySleepEntry(
    wakeDate: DateTime(2026, 9, day),
    session: SleepSummary(
      duration: Duration(minutes: minutes),
      startTime: end.subtract(Duration(minutes: minutes)),
      endTime: end,
    ),
  );
}

void main() {
  test('sleep debt sums shortfall below the 7h target', () {
    final debt = computeSleepDebt([
      _night(1, 6 * 60), // 60 min short
      _night(2, 8 * 60), // over target, no credit
      _night(3, 5 * 60 + 30), // 90 min short
      DailySleepEntry(wakeDate: DateTime(2026, 9, 4)), // no data
    ]);

    expect(debt.nightsBelowTarget, 2);
    expect(debt.estimatedDebt, const Duration(minutes: 150));
  });
}
