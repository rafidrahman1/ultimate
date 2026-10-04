import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_stage_stats.dart';

HealthDataPoint _p(HealthDataType type, DateTime from, DateTime to) =>
    HealthDataPoint(
      uuid: '${type.name}-${from.microsecondsSinceEpoch}',
      value: NumericHealthValue(numericValue: to.difference(from).inMinutes),
      type: type,
      unit: HealthDataUnit.MINUTE,
      dateFrom: from,
      dateTo: to,
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'd',
      sourceId: 'com.sec.android.app.shealth',
      sourceName: 'Samsung Health',
    );

/// A night ending on the morning of [wake]: bed 23:30, up 06:30 (7h in bed).
List<HealthDataPoint> _night(DateTime wake, {bool stages = true}) {
  final bed = DateTime(wake.year, wake.month, wake.day - 1, 23, 30);
  DateTime at(int minutes) => bed.add(Duration(minutes: minutes));
  return [
    _p(HealthDataType.SLEEP_SESSION, bed, at(420)),
    if (stages) ...[
      _p(HealthDataType.SLEEP_LIGHT, at(0), at(150)),
      _p(HealthDataType.SLEEP_DEEP, at(150), at(220)),
      _p(HealthDataType.SLEEP_AWAKE, at(220), at(230)),
      _p(HealthDataType.SLEEP_REM, at(230), at(300)),
      _p(HealthDataType.SLEEP_LIGHT, at(300), at(380)),
      _p(HealthDataType.SLEEP_AWAKE, at(380), at(390)),
      _p(HealthDataType.SLEEP_REM, at(390), at(420)),
    ],
  ];
}

MonthlyHealthSummary _summary(List<HealthDataPoint> points) =>
    MonthlyHealthSummary.fromFetch(
      MonthlyHealthFetchResult(
        points: points,
        periodStart: DateTime(2026, 9, 1),
        periodEnd: DateTime(2026, 9, 10, 23, 59),
        dayCount: 10,
      ),
    );

void main() {
  test('attaches stage totals to a night', () {
    final s = _summary(_night(DateTime(2026, 9, 3)));
    final night = s.dailySleep.firstWhere((n) => n.hasData).session!;
    final stages = night.stages!;
    expect(stages.deep, const Duration(minutes: 70));
    expect(stages.light, const Duration(minutes: 230));
    expect(stages.rem, const Duration(minutes: 100));
    expect(stages.awake, const Duration(minutes: 20));
    expect(stages.awakeEpisodes, 2);
    expect(stages.asleep, const Duration(minutes: 400));
    expect(stages.deepShare, closeTo(70 / 400, 1e-9));
    expect(stages.efficiency, closeTo(400 / 420, 1e-9));
  });

  test('has no stages when the source only records the session', () {
    final s = _summary(_night(DateTime(2026, 9, 3), stages: false));
    final night = s.dailySleep.firstWhere((n) => n.hasData).session!;
    expect(night.stages, isNull);
  });

  test('efficiency is unknown when no awake time was recorded', () {
    const stages = SleepStages(
      deep: Duration(hours: 1),
      light: Duration(hours: 4),
      rem: Duration(hours: 1),
      awake: Duration.zero,
    );
    expect(stages.efficiency, isNull);
  });

  test('averages stages over staged nights only', () {
    final s = _summary([
      ..._night(DateTime(2026, 9, 3)),
      ..._night(DateTime(2026, 9, 4)),
      ..._night(DateTime(2026, 9, 5)),
      ..._night(DateTime(2026, 9, 6), stages: false),
    ]);
    final stats = computeSleepStageStats(s.dailySleep)!;
    expect(stats.nights, 3);
    expect(stats.avgDeep, const Duration(minutes: 70));
    expect(stats.avgAwakeEpisodes, 2);
    expect(stats.avgEfficiency, closeTo(400 / 420, 1e-9));
    expect(
      stats.deepShare + stats.remShare + stats.lightShare,
      closeTo(1, 1e-9),
    );
  });

  test('needs a few staged nights before averaging', () {
    final s = _summary([
      ..._night(DateTime(2026, 9, 3)),
      ..._night(DateTime(2026, 9, 4)),
    ]);
    expect(computeSleepStageStats(s.dailySleep), isNull);
  });
}
