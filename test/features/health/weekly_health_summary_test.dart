import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';

HealthDataPoint _sleepSessionPoint({
  required DateTime from,
  required DateTime to,
}) {
  return HealthDataPoint(
    uuid: 'sleep-$from-$to',
    value: NumericHealthValue(numericValue: 0),
    type: HealthDataType.SLEEP_SESSION,
    unit: HealthDataUnit.NO_UNIT,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'device',
    sourceId: 'id',
    sourceName: 'com.sec.android.app.shealth',
  );
}

void main() {
  test('computes weekly averages from seven-day fetch', () {
    final periodEnd = DateTime(2026, 5, 23, 18);
    final periodStart = DateTime(2026, 5, 17);
    final dailySteps = <DateTime, int>{
      DateTime(2026, 5, 17): 4000,
      DateTime(2026, 5, 18): 6000,
      DateTime(2026, 5, 19): 8000,
      DateTime(2026, 5, 20): 5000,
      DateTime(2026, 5, 21): 7000,
      DateTime(2026, 5, 22): 9000,
      DateTime(2026, 5, 23): 3000,
    };

    final sleepNight = _sleepSessionPoint(
      from: DateTime(2026, 5, 22, 23, 0),
      to: DateTime(2026, 5, 23, 7, 0),
    );

    final fetch = WeeklyHealthFetchResult(
      points: [sleepNight],
      periodStart: periodStart,
      periodEnd: periodEnd,
      dailySteps: dailySteps,
      todaySteps: 3000,
    );

    final summary = WeeklyHealthSummary.fromWeeklyFetch(fetch);

    expect(summary.avgStepsPerDay, closeTo(6000, 0.1));
    expect(summary.sleepNightsTracked, 1);
    expect(summary.avgSleepPerDay, const Duration(hours: 8));
    expect(summary.periodRangeLabel, contains('2026'));
  });

  test('computes bmi from latest weight and height', () {
    final periodEnd = DateTime(2026, 5, 23, 12);
    final periodStart = DateTime(2026, 5, 17);
    final weight = HealthDataPoint(
      uuid: 'weight-1',
      value: NumericHealthValue(numericValue: 70),
      type: HealthDataType.WEIGHT,
      unit: HealthDataUnit.KILOGRAM,
      dateFrom: DateTime(2026, 5, 22, 8),
      dateTo: DateTime(2026, 5, 22, 8),
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'device',
      sourceId: 'id',
      sourceName: 'com.sec.android.app.shealth',
    );
    final height = HealthDataPoint(
      uuid: 'height-1',
      value: NumericHealthValue(numericValue: 1.75),
      type: HealthDataType.HEIGHT,
      unit: HealthDataUnit.METER,
      dateFrom: DateTime(2026, 1, 1),
      dateTo: DateTime(2026, 1, 1),
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'device',
      sourceId: 'id',
      sourceName: 'com.sec.android.app.shealth',
    );

    final summary = WeeklyHealthSummary.fromWeeklyFetch(
      WeeklyHealthFetchResult(
        points: [weight, height],
        periodStart: periodStart,
        periodEnd: periodEnd,
        dailySteps: const {},
        todaySteps: 0,
      ),
    );

    expect(summary.latestWeightKg, 70);
    expect(summary.heightMeters, 1.75);
    expect(summary.bmi, closeTo(22.9, 0.1));
  });
}
