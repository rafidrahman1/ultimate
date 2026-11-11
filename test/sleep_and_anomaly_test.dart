import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/health/analysis/sleep_metrics.dart';
import 'package:personal/features/health/data/health_summary.dart';
import 'package:personal/features/location/analysis/place_stats.dart';
import 'package:personal/features/results/pipeline/anomaly_ranking.dart';

DailySleepEntry night(
  int day,
  Duration? slept, {
  Duration nap = Duration.zero,
}) {
  final wake = DateTime(2026, 11, day, 7);
  return DailySleepEntry(
    wakeDate: DateTime(2026, 11, day),
    napDuration: nap,
    session: slept == null
        ? null
        : SleepSummary(
            duration: slept,
            startTime: wake.subtract(slept),
            endTime: wake,
          ),
  );
}

void main() {
  group('computeSleepDebt', () {
    test('adds up the shortfall against the 7 hour target', () {
      final debt = computeSleepDebt([
        night(1, const Duration(hours: 5)),
        night(2, const Duration(hours: 8)),
        night(3, const Duration(hours: 6, minutes: 30)),
        night(4, null),
      ]);
      expect(debt.nightsBelowTarget, 2);
      expect(debt.estimatedDebt, const Duration(hours: 2, minutes: 30));
    });

    test('naps count toward the target', () {
      final debt = computeSleepDebt([
        night(1, const Duration(hours: 6), nap: const Duration(hours: 1)),
      ]);
      expect(debt.nightsBelowTarget, 0);
      expect(debt.estimatedDebt, Duration.zero);
    });
  });

  group('rankAnomalyCandidates', () {
    const debt = AnomalyCandidate(
      label: 'debt',
      severity: 3,
      recurrence: 1,
      crossDomain: 1,
      priorityTier: 1,
    );
    const big = AnomalyCandidate(
      label: 'big',
      severity: 9,
      recurrence: 9,
      crossDomain: 9,
    );
    const small = AnomalyCandidate(
      label: 'small',
      severity: 2,
      recurrence: 1,
      crossDomain: 1,
    );
    const none = AnomalyCandidate(
      label: 'none',
      severity: 0,
      recurrence: 9,
      crossDomain: 9,
      priorityTier: 1,
    );

    test('orders by tier, then impact, and drops zero severity', () {
      final ranked = rankAnomalyCandidates([small, none, big, debt]);
      expect(ranked.map((c) => c.label), ['debt', 'big', 'small']);
    });

    test('impact score weights severity most', () {
      expect(big.impactScore, 9 * 5 + 9 * 3 + 9 * 2);
      expect(isSignificantAnomaly(none), isFalse);
      expect(isSignificantAnomaly(small), isTrue);
    });
  });

  group('CommuteStats', () {
    final samples = [
      CommuteSample(
        departed: DateTime(2026, 11, 2, 8, 0),
        arrived: DateTime(2026, 11, 2, 8, 40),
      ),
      CommuteSample(
        departed: DateTime(2026, 11, 3, 8, 30),
        arrived: DateTime(2026, 11, 3, 9, 30),
      ),
    ];

    test('averages duration and departure time', () {
      expect(
        CommuteStats.averageDuration(samples),
        const Duration(minutes: 50),
      );
      expect(CommuteStats.averageDepartureMinutes(samples), 8 * 60 + 15);
    });

    test('no samples means no averages', () {
      expect(CommuteStats.averageDuration(const []), isNull);
      expect(CommuteStats.averageDepartureMinutes(const []), isNull);
      expect(CommuteStats.empty.hasData, isFalse);
    });
  });
}
