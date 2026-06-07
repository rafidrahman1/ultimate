import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:Personal/features/health/health_service.dart';
import 'package:Personal/features/health/health_summary.dart';

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

DailySleepEntry _day(MonthlyHealthSummary summary, DateTime wakeDate) {
  return summary.dailySleep.firstWhere(
    (d) =>
        d.wakeDate.year == wakeDate.year &&
        d.wakeDate.month == wakeDate.month &&
        d.wakeDate.day == wakeDate.day,
  );
}

void main() {
  test('builds seven daily sleep slots from fetch', () {
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

    final fetch = MonthlyHealthFetchResult(
      points: [sleepNight],
      periodStart: periodStart,
      periodEnd: periodEnd,
      dailySteps: dailySteps,
      dayCount: 7,
    );

    final summary = MonthlyHealthSummary.fromFetch(fetch);

    expect(summary.avgStepsPerDay, closeTo(6000, 0.1));
    expect(summary.dailySleep, hasLength(7));
    expect(summary.sleepNightsTracked, 1);
    expect(summary.periodRangeLabel, contains('2026'));

    final may23 = _day(summary, DateTime(2026, 5, 23));
    expect(may23.hasData, isTrue);
    expect(may23.session!.duration, const Duration(hours: 8));
    expect(formatTime(may23.session!.startTime), '23:00');
    expect(formatTime(may23.session!.endTime), '07:00');

    expect(_day(summary, DateTime(2026, 5, 22)).hasData, isFalse);

    expect(summary.toSleepPromptText(), contains('23 May 2026'));
    expect(summary.toSleepPromptText(), contains('8h 0m'));
    expect(summary.toSleepPromptText(), contains('bedtime 23:00'));
    expect(summary.toSleepPromptText(), contains('wake 07:00'));
    expect(summary.toSleepPromptText(), isNot(contains('no data')));
    expect(summary.toSleepPromptText(), isNot(contains('22 May 2026')));
  });

  test('sleep uses only nights with data in the last 7 days', () {
    final periodEnd = DateTime(2026, 5, 23, 12);
    final periodStart = DateTime(2026, 5, 17);
    final fetch = MonthlyHealthFetchResult(
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
      dayCount: 7,
    );

    final summary = MonthlyHealthSummary.fromFetch(fetch);

    expect(summary.sleepNightsTracked, 3);
    expect(_day(summary, DateTime(2026, 5, 21)).session!.duration,
        const Duration(hours: 8));
    expect(_day(summary, DateTime(2026, 5, 22)).session!.duration,
        const Duration(hours: 8));
    expect(_day(summary, DateTime(2026, 5, 23)).session!.duration,
        const Duration(hours: 8));
    expect(_day(summary, DateTime(2026, 5, 17)).hasData, isFalse);
  });

  test('uses session duration when stage sleep is incomplete', () {
    final periodEnd = DateTime(2026, 5, 23, 12);
    final periodStart = DateTime(2026, 5, 17);
    final session = _sleepSessionPoint(
      from: DateTime(2026, 5, 22, 23, 0),
      to: DateTime(2026, 5, 23, 7, 0),
    );
    // Non-asleep stage only; duration should still come from the session block.
    final partialStage = _sleepStagePoint(
      type: HealthDataType.SLEEP_AWAKE,
      from: DateTime(2026, 5, 23, 1, 0),
      to: DateTime(2026, 5, 23, 2, 30),
    );

    final summary = MonthlyHealthSummary.fromFetch(
      MonthlyHealthFetchResult(
        points: [session, partialStage],
        periodStart: periodStart,
        periodEnd: periodEnd,
        dailySteps: const {},
        dayCount: 7,
      ),
    );

    expect(summary.sleepNightsTracked, 1);
    expect(_day(summary, DateTime(2026, 5, 23)).session!.duration,
        const Duration(hours: 8));
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

    final summary = MonthlyHealthSummary.fromFetch(
      MonthlyHealthFetchResult(
        points: [samsungNight, nonSamsungNight],
        periodStart: periodStart,
        periodEnd: periodEnd,
        dailySteps: const {},
        dayCount: 7,
      ),
    );

    expect(summary.sleepNightsTracked, 1);
    final day = _day(summary, DateTime(2026, 5, 23));
    expect(day.session!.duration, const Duration(hours: 8));
    expect(formatTime(day.session!.startTime), '23:00');
    expect(formatTime(day.session!.endTime), '07:00');
  });

  test('ignores sparse Samsung stages when only non-Samsung has the night session',
      () {
    final periodEnd = DateTime(2026, 5, 10, 12);
    final periodStart = DateTime(2026, 5, 1);
    final nonSamsungNight = _sleepSessionPoint(
      from: DateTime(2026, 5, 4, 23, 30),
      to: DateTime(2026, 5, 5, 7, 0),
      sourceName: 'com.google.android.apps.fitness',
    );
    final samsungAwakeFragment = _sleepStagePoint(
      type: HealthDataType.SLEEP_AWAKE,
      from: DateTime(2026, 5, 5, 6, 0),
      to: DateTime(2026, 5, 5, 6, 10),
      sourceName: 'com.sec.android.app.shealth',
    );

    final summary = MonthlyHealthSummary.fromFetch(
      MonthlyHealthFetchResult(
        points: [nonSamsungNight, samsungAwakeFragment],
        periodStart: periodStart,
        periodEnd: periodEnd,
        dailySteps: const {},
        dayCount: 10,
      ),
    );

    expect(summary.sleepNightsTracked, 1);
    final day = _day(summary, DateTime(2026, 5, 5));
    expect(day.hasData, isTrue);
    expect(day.session!.duration, const Duration(hours: 7, minutes: 30));
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

    final summary = MonthlyHealthSummary.fromFetch(
      MonthlyHealthFetchResult(
        points: [samsungNight, nonSamsungNight],
        periodStart: periodStart,
        periodEnd: periodEnd,
        dailySteps: const {},
        dayCount: 7,
      ),
    );

    expect(summary.sleepNightsTracked, 2);
    expect(_day(summary, DateTime(2026, 5, 22)).session!.duration,
        const Duration(hours: 8));
    expect(_day(summary, DateTime(2026, 5, 23)).session!.duration,
        const Duration(hours: 7));
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

    final summary = MonthlyHealthSummary.fromFetch(
      MonthlyHealthFetchResult(
        points: [firstSession, secondSession, daytimeNap],
        periodStart: periodStart,
        periodEnd: periodEnd,
        dailySteps: const {},
        dayCount: 7,
      ),
    );

    expect(summary.sleepNightsTracked, 1);
    final day = _day(summary, DateTime(2026, 5, 22));
    expect(day.session!.duration, const Duration(hours: 6, minutes: 35));
    expect(formatTime(day.session!.startTime), '00:30');
    expect(formatTime(day.session!.endTime), '07:50');
  });

  test('uses asleep stages for duration when sessions span awake gaps', () {
    final periodEnd = DateTime(2026, 5, 25, 12);
    final periodStart = DateTime(2026, 5, 19);
    final firstSession = _sleepSessionPoint(
      from: DateTime(2026, 5, 25, 3, 6),
      to: DateTime(2026, 5, 25, 8, 4),
    );
    final secondSession = _sleepSessionPoint(
      from: DateTime(2026, 5, 25, 8, 34),
      to: DateTime(2026, 5, 25, 10, 50),
    );
    final asleep1 = _sleepStagePoint(
      type: HealthDataType.SLEEP_ASLEEP,
      from: DateTime(2026, 5, 25, 3, 6),
      to: DateTime(2026, 5, 25, 7, 34),
    );
    final asleep2 = _sleepStagePoint(
      type: HealthDataType.SLEEP_ASLEEP,
      from: DateTime(2026, 5, 25, 8, 34),
      to: DateTime(2026, 5, 25, 10, 27),
    );

    final summary = MonthlyHealthSummary.fromFetch(
      MonthlyHealthFetchResult(
        points: [firstSession, secondSession, asleep1, asleep2],
        periodStart: periodStart,
        periodEnd: periodEnd,
        dailySteps: const {},
        dayCount: 7,
      ),
    );

    final day = _day(summary, DateTime(2026, 5, 25));
    expect(day.session!.duration, const Duration(hours: 6, minutes: 21));
    expect(formatTime(day.session!.startTime), '03:06');
    expect(formatTime(day.session!.endTime), '10:50');
  });

  test('sums split overnight sessions on the same wake day', () {
    final periodEnd = DateTime(2026, 5, 26, 12);
    final periodStart = DateTime(2026, 5, 20);
    final earlyMorning = _sleepSessionPoint(
      from: DateTime(2026, 5, 26, 1, 37),
      to: DateTime(2026, 5, 26, 3, 25),
    );
    final laterMorning = _sleepSessionPoint(
      from: DateTime(2026, 5, 26, 6, 30),
      to: DateTime(2026, 5, 26, 9, 26),
    );

    final summary = MonthlyHealthSummary.fromFetch(
      MonthlyHealthFetchResult(
        points: [earlyMorning, laterMorning],
        periodStart: periodStart,
        periodEnd: periodEnd,
        dailySteps: const {},
        dayCount: 7,
      ),
    );

    final day = _day(summary, DateTime(2026, 5, 26));
    expect(day.session!.duration, const Duration(hours: 4, minutes: 44));
    expect(formatTime(day.session!.startTime), '01:37');
    expect(formatTime(day.session!.endTime), '09:26');
  });

  test('falls back to session ending on wake day when prime filter misses', () {
    final periodEnd = DateTime(2026, 5, 10, 12);
    final periodStart = DateTime(2026, 5, 1);
    final lateWakeSession = _sleepSessionPoint(
      from: DateTime(2026, 5, 4, 19, 30),
      to: DateTime(2026, 5, 5, 10, 30),
    );

    final summary = MonthlyHealthSummary.fromFetch(
      MonthlyHealthFetchResult(
        points: [lateWakeSession],
        periodStart: periodStart,
        periodEnd: periodEnd,
        dailySteps: const {},
        dayCount: 10,
      ),
    );

    expect(_day(summary, DateTime(2026, 5, 5)).hasData, isTrue);
  });

  test('avg steps uses days with data like Samsung Health, not zero-step days', () {
    final dailySteps = <DateTime, int>{};
    for (var day = 1; day <= 31; day++) {
      dailySteps[DateTime(2026, 5, day)] = day <= 23 ? 3380 : 0;
    }

    final summary = MonthlyHealthSummary.fromFetch(
      MonthlyHealthFetchResult(
        points: const [],
        periodStart: DateTime(2026, 5, 1),
        periodEnd: DateTime(2026, 5, 31, 23, 59, 59, 999, 999),
        dailySteps: dailySteps,
        dayCount: 31,
      ),
    );

    expect(summary.avgStepsPerDay, closeTo(3380, 0.1));
  });

  test('toSleepPromptText is empty when week has no sleep', () {
    final summary = MonthlyHealthSummary.fromFetch(
      MonthlyHealthFetchResult(
        points: const [],
        periodStart: DateTime(2026, 5, 17),
        periodEnd: DateTime(2026, 5, 23),
        dailySteps: const {},
        dayCount: 7,
      ),
    );

    expect(summary.toSleepPromptText(), isEmpty);
  });
}
