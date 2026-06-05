import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:Personal/features/health/step_counter.dart';

HealthDataPoint _stepPoint({
  required String sourceName,
  required double count,
  required DateTime from,
  required DateTime to,
}) {
  return HealthDataPoint(
    uuid: '$sourceName-$from-$count',
    value: NumericHealthValue(numericValue: count),
    type: HealthDataType.STEPS,
    unit: HealthDataUnit.COUNT,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'device',
    sourceId: 'id',
    sourceName: sourceName,
  );
}

void main() {
  final midnight = DateTime(2026, 5, 22);
  final now = DateTime(2026, 5, 22, 18);

  test('resolveTodaySteps prefers higher per-source total over aggregate', () {
    final points = [
      _stepPoint(
        sourceName: 'com.sec.android.app.shealth',
        count: 3231,
        from: midnight,
        to: now,
      ),
      _stepPoint(
        sourceName: 'android',
        count: 2033,
        from: midnight,
        to: now,
      ),
    ];

    expect(
      resolveTodaySteps(
        aggregatedSteps: 2033,
        stepPoints: points,
        start: midnight,
        end: now,
      ),
      3231,
    );
  });

  test('resolveTodaySteps does not sum overlapping sources', () {
    final points = [
      _stepPoint(
        sourceName: 'com.sec.android.app.shealth',
        count: 2000,
        from: midnight,
        to: now,
      ),
      _stepPoint(
        sourceName: 'android',
        count: 2000,
        from: midnight,
        to: now,
      ),
    ];

    expect(
      resolveTodaySteps(
        aggregatedSteps: 2000,
        stepPoints: points,
        start: midnight,
        end: now,
      ),
      2000,
    );
  });

  test('resolveTodaySteps uses aggregate when it is highest', () {
    expect(
      resolveTodaySteps(
        aggregatedSteps: 4000,
        stepPoints: [
          _stepPoint(
            sourceName: 'android',
            count: 1000,
            from: midnight,
            to: now,
          ),
        ],
        start: midnight,
        end: now,
      ),
      4000,
    );
  });
}
