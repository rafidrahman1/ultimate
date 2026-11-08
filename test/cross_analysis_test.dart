import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecasts_screen.dart';
import 'package:personal/features/results/pipeline/cross_analysis.dart';
import 'package:personal/features/screen_time/data/screen_time_models.dart';

DateTime day(int n) => DateTime(2026, 10, n);

void main() {
  test('heavy screen days followed by shorter sleep are flagged', () {
    final screen = <DateTime, double>{};
    final sleep = <DateTime, double>{};
    for (var d = 1; d <= 20; d++) {
      final heavy = d.isEven;
      screen[day(d)] = heavy ? 7 : 3;
      // Sleep on the following morning.
      sleep[day(d + 1)] = (heavy ? 5.5 : 7.5) + (d % 3) * 0.05;
    }
    final out = computeCrossInsights(
      CrossInputs(screenHours: screen, sleepHours: sleep),
    );
    final link = out.firstWhere((e) => e.title == 'Screen time → sleep');
    expect(link.notable, isTrue);
    expect(link.tone, CrossTone.watch);
    expect(link.r, lessThan(-0.9));
    expect(crossInsightsToText(out), contains('Screen time → sleep'));
  });

  test('too few overlapping days yields nothing', () {
    final out = computeCrossInsights(
      CrossInputs(
        screenHours: {for (var d = 1; d <= 4; d++) day(d): 3.0 + d},
        sleepHours: {for (var d = 1; d <= 5; d++) day(d): 7.0},
      ),
    );
    expect(out, isEmpty);
    expect(crossInsightsToText(out), contains('Not enough'));
  });

  test('unrelated series are reported as no clear link', () {
    final screen = <DateTime, double>{};
    final spend = <DateTime, double>{};
    const s = [3.0, 5.0, 4.0, 6.0, 3.5, 5.5, 4.5, 6.5, 3.2, 5.2];
    const p = [
      200.0,
      300.0,
      100.0,
      200.0,
      300.0,
      100.0,
      200.0,
      200.0,
      100.0,
      300.0,
    ];
    for (var d = 0; d < 10; d++) {
      screen[day(d + 1)] = s[d];
      spend[day(d + 1)] = p[d];
    }
    final out = computeCrossInsights(
      CrossInputs(screenHours: screen, spend: spend),
    );
    final link = out.firstWhere((e) => e.title == 'Screen time → spending');
    expect(link.notable, isFalse);
    expect(link.detail, startsWith('No clear link'));
  });

  test('late arrivals compared with sleep the night before', () {
    final sleep = <DateTime, double>{};
    final late = <DateTime>{};
    final onTime = <DateTime>{};
    for (var d = 1; d <= 12; d++) {
      final isLate = d % 3 == 0;
      sleep[day(d)] = isLate ? 5.0 + (d % 2) * 0.2 : 7.4 + (d % 2) * 0.2;
      (isLate ? late : onTime).add(day(d));
    }
    final out = computeCrossInsights(
      CrossInputs(sleepHours: sleep, lateDays: late, onTimeDays: onTime),
    );
    final link = out.firstWhere((e) => e.title == 'Sleep → late arrivals');
    expect(link.notable, isTrue);
    expect(link.tone, CrossTone.watch);
  });

  test('screen time forecast needs five days and flags a rising week', () {
    ScreenTimeSummary summary(List<double> hours) => ScreenTimeSummary([
      for (var k = 0; k < hours.length; k++)
        AppUsageEntry(
          day: day(k + 1),
          packageName: 'a',
          label: 'A',
          duration: Duration(minutes: (hours[k] * 60).round()),
        ),
    ]);
    final now = DateTime(2026, 10, 20, 12);
    expect(
      forecastScreenTime(LifeInputs(now: now, screen: summary([3, 3, 3]))),
      isNull,
    );
    final rising = forecastScreenTime(
      LifeInputs(
        now: now,
        screen: summary([3, 3, 3, 3, 3, 3, 3, 5, 5, 5, 5, 5, 5, 5]),
      ),
    );
    expect(rising, isNotNull);
    expect(rising!.attention, isTrue);
    expect(rising.headline, contains('/day'));
  });
}
