import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:personal/features/health/health_summary.dart';

HealthDataPoint _workoutPoint({
  required DateTime from,
  required DateTime to,
  int? calories,
}) {
  return HealthDataPoint(
    uuid: 'workout-$from-$to',
    value: WorkoutHealthValue(
      workoutActivityType: HealthWorkoutActivityType.WALKING,
      totalEnergyBurned: calories,
      totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
    ),
    type: HealthDataType.WORKOUT,
    unit: HealthDataUnit.NO_UNIT,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'device',
    sourceId: 'id',
    sourceName: 'health_connect',
  );
}

HealthDataPoint _stepPoint({
  required DateTime from,
  required DateTime to,
  required double steps,
}) {
  return HealthDataPoint(
    uuid: 'steps-$from-$to-$steps',
    value: NumericHealthValue(numericValue: steps),
    type: HealthDataType.STEPS,
    unit: HealthDataUnit.COUNT,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'device',
    sourceId: 'id',
    sourceName: 'health_connect',
  );
}

HealthDataPoint _numericPoint({
  required HealthDataType type,
  required HealthDataUnit unit,
  required double value,
  required DateTime from,
  required DateTime to,
}) {
  return HealthDataPoint(
    uuid: '$type-$from-$to-$value',
    value: NumericHealthValue(numericValue: value),
    type: type,
    unit: unit,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'device',
    sourceId: 'id',
    sourceName: 'health_connect',
  );
}

void main() {
  test('counts explicit workout sessions', () {
    final now = DateTime(2026, 5, 23, 12);
    final summary = HealthSummary.fromData(
      [
        _workoutPoint(
          from: now.subtract(const Duration(minutes: 30)),
          to: now,
          calories: 180,
        ),
      ],
      todaySteps: 3200,
    );

    expect(summary.workoutCount, 1);
    expect(summary.totalWorkoutCalories, 180);
    expect(summary.walkedDuration, const Duration(minutes: 30));
    expect(summary.walkedDistanceKm, closeTo(0, 0.001));
  });

  test('infers walking session from sustained step segment', () {
    final now = DateTime(2026, 5, 23, 12);
    final summary = HealthSummary.fromData(
      [
        _stepPoint(
          from: now.subtract(const Duration(minutes: 30)),
          to: now,
          steps: 2600,
        ),
      ],
      todaySteps: 2600,
    );

    expect(summary.workoutCount, 1);
    expect(summary.totalWorkoutCalories, 104);
    expect(summary.walkedDuration, const Duration(minutes: 30));
    expect(summary.walkedDistanceKm, closeTo(2.03, 0.05));
  });

  test('does not infer workout for low activity', () {
    final now = DateTime(2026, 5, 23, 12);
    final summary = HealthSummary.fromData(
      [
        _stepPoint(
          from: now.subtract(const Duration(minutes: 15)),
          to: now,
          steps: 600,
        ),
      ],
      todaySteps: 600,
    );

    expect(summary.workoutCount, 0);
    expect(summary.walkedDuration, Duration.zero);
    expect(summary.walkedDistanceKm, 0);
  });

  test('uses step-count fallback when only aggregate steps exist', () {
    final summary = HealthSummary.fromData(const [], todaySteps: 3000);
    expect(summary.workoutCount, 1);
    expect(summary.walkedDuration, const Duration(minutes: 36));
    expect(summary.walkedDistanceKm, closeTo(2.34, 0.05));
    expect(summary.totalWorkoutCalories, 120);
  });

  test('uses distance fallback when workout is missing', () {
    final now = DateTime(2026, 5, 23, 12);
    final summary = HealthSummary.fromData(
      [
        _numericPoint(
          type: HealthDataType.DISTANCE_DELTA,
          unit: HealthDataUnit.METER,
          value: 2590,
          from: now.subtract(const Duration(minutes: 30)),
          to: now,
        ),
      ],
      todaySteps: 0,
    );

    expect(summary.workoutCount, 1);
    expect(summary.walkedDuration, const Duration(minutes: 30));
    expect(summary.walkedDistanceKm, closeTo(2.59, 0.01));
    expect(summary.totalWorkoutCalories, 223);
  });
}
