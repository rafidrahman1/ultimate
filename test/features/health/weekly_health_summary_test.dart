import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';

HealthDataPoint _sleepSessionPoint({
  required DateTime from,
  required DateTime to,
  String sourceName = 'com.sec.android.app.shealth',
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
    sourceName: sourceName,
  );
}

HealthDataPoint _sleepStagePoint({
  required HealthDataType type,
  required DateTime from,
  required DateTime to,
  String sourceName = 'com.sec.android.app.shealth',
}) {
  return HealthDataPoint(
    uuid: 'stage-$type-$from-$to',
    value: NumericHealthValue(numericValue: 0),
    type: type,
    unit: HealthDataUnit.NO_UNIT,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'device',
    sourceId: 'id',
    sourceName: sourceName,
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
    expect(summary.avgBedtime, DateTime(2000, 1, 1, 23, 0));
    expect(summary.avgWakeTime, DateTime(2000, 1, 1, 7, 0));
    expect(summary.periodRangeLabel, contains('2026'));
  });

  test('sleep averages use only nights with data in the last 7 days', () {
    final periodEnd = DateTime(2026, 5, 23, 12);
    final periodStart = DateTime(2026, 5, 17);
    final fetch = WeeklyHealthFetchResult(
      points: [
        _sleepSessionPoint(
          from: DateTime(2026, 5, 20, 23, 0),
          to: DateTime(2026, 5, 21, 7, 0),
        ),
        _sleepSessionPoint(
          from: DateTime(2026, 5, 21, 22, 30),
          to: DateTime(2026, 5, 22, 6, 30),
        ),
        _sleepSessionPoint(
          from: DateTime(2026, 5, 22, 23, 30),
          to: DateTime(2026, 5, 23, 7, 30),
        ),
      ],
      periodStart: periodStart,
      periodEnd: periodEnd,
      dailySteps: const {},
      todaySteps: 0,
    );

    final summary = WeeklyHealthSummary.fromWeeklyFetch(fetch);

    expect(summary.sleepNightsTracked, 3);
    expect(summary.avgSleepPerDay, const Duration(hours: 8));
    expect(summary.avgBedtime, DateTime(2000, 1, 1, 23, 0));
    expect(summary.avgWakeTime, DateTime(2000, 1, 1, 7, 0));
  });

  test('uses session duration when stage sleep is incomplete', () {
    final periodEnd = DateTime(2026, 5, 23, 12);
    final periodStart = DateTime(2026, 5, 17);
    final session = _sleepSessionPoint(
      from: DateTime(2026, 5, 22, 23, 0),
      to: DateTime(2026, 5, 23, 7, 0),
    );
    final partialStage = _sleepStagePoint(
      type: HealthDataType.SLEEP_LIGHT,
      from: DateTime(2026, 5, 23, 1, 0),
      to: DateTime(2026, 5, 23, 2, 30),
    );

    final summary = WeeklyHealthSummary.fromWeeklyFetch(
      WeeklyHealthFetchResult(
        points: [session, partialStage],
        periodStart: periodStart,
        periodEnd: periodEnd,
        dailySteps: const {},
        todaySteps: 0,
      ),
    );

    expect(summary.sleepNightsTracked, 1);
    expect(summary.avgSleepPerDay, const Duration(hours: 8));
  });

  test('prefers Samsung sleep records for the same wake day', () {
    final periodEnd = DateTime(2026, 5, 23, 12);
    final periodStart = DateTime(2026, 5, 17);
    final samsungNight = _sleepSessionPoint(
      from: DateTime(2026, 5, 22, 23, 0),
      to: DateTime(2026, 5, 23, 7, 0),
      sourceName: 'com.sec.android.app.shealth',
    );
    final nonSamsungNight = _sleepSessionPoint(
      from: DateTime(2026, 5, 23, 0, 30),
      to: DateTime(2026, 5, 23, 2, 30),
      sourceName: 'com.google.android.apps.fitness',
    );

    final summary = WeeklyHealthSummary.fromWeeklyFetch(
      WeeklyHealthFetchResult(
        points: [samsungNight, nonSamsungNight],
        periodStart: periodStart,
        periodEnd: periodEnd,
        dailySteps: const {},
        todaySteps: 0,
      ),
    );

    expect(summary.sleepNightsTracked, 1);
    expect(summary.avgSleepPerDay, const Duration(hours: 8));
    expect(summary.avgBedtime, DateTime(2000, 1, 1, 23, 0));
    expect(summary.avgWakeTime, DateTime(2000, 1, 1, 7, 0));
  });

  test('falls back to non-Samsung records when Samsung missing that day', () {
    final periodEnd = DateTime(2026, 5, 23, 12);
    final periodStart = DateTime(2026, 5, 17);
    final samsungNight = _sleepSessionPoint(
      from: DateTime(2026, 5, 21, 23, 0),
      to: DateTime(2026, 5, 22, 7, 0),
      sourceName: 'com.sec.android.app.shealth',
    );
    final nonSamsungNight = _sleepSessionPoint(
      from: DateTime(2026, 5, 22, 23, 30),
      to: DateTime(2026, 5, 23, 6, 30),
      sourceName: 'com.google.android.apps.fitness',
    );

    final summary = WeeklyHealthSummary.fromWeeklyFetch(
      WeeklyHealthFetchResult(
        points: [samsungNight, nonSamsungNight],
        periodStart: periodStart,
        periodEnd: periodEnd,
        dailySteps: const {},
        todaySteps: 0,
      ),
    );

    expect(summary.sleepNightsTracked, 2);
    expect(summary.avgSleepPerDay, const Duration(hours: 7, minutes: 30));
  });

  test('uses primary merged night when date has multiple sleep sessions', () {
    final periodEnd = DateTime(2026, 5, 23, 12);
    final periodStart = DateTime(2026, 5, 17);
    final firstSession = _sleepSessionPoint(
      from: DateTime(2026, 5, 22, 0, 30),
      to: DateTime(2026, 5, 22, 4, 0),
    );
    final secondSession = _sleepSessionPoint(
      from: DateTime(2026, 5, 22, 4, 45),
      to: DateTime(2026, 5, 22, 7, 50),
    );
    final daytimeNap = _sleepSessionPoint(
      from: DateTime(2026, 5, 22, 10, 0),
      to: DateTime(2026, 5, 22, 10, 30),
    );

    final summary = WeeklyHealthSummary.fromWeeklyFetch(
      WeeklyHealthFetchResult(
        points: [firstSession, secondSession, daytimeNap],
        periodStart: periodStart,
        periodEnd: periodEnd,
        dailySteps: const {},
        todaySteps: 0,
      ),
    );

    expect(summary.sleepNightsTracked, 1);
    expect(summary.avgSleepPerDay, const Duration(hours: 7, minutes: 20));
    expect(summary.avgBedtime, DateTime(2000, 1, 1, 0, 30));
    expect(summary.avgWakeTime, DateTime(2000, 1, 1, 7, 50));
  });
}
