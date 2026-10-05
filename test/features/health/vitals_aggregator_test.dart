import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import 'package:personal/features/health/vitals_aggregator.dart';
import 'package:personal/features/health/vitals_models.dart';

HealthDataPoint _point(
  HealthDataType type,
  num value,
  DateTime from, {
  DateTime? to,
  String source = 'com.sec.android.app.shealth',
  HealthDataUnit unit = HealthDataUnit.NO_UNIT,
}) => HealthDataPoint(
  uuid: '${type.name}-${from.microsecondsSinceEpoch}-$value-$source',
  value: NumericHealthValue(numericValue: value),
  type: type,
  unit: unit,
  dateFrom: from,
  dateTo: to ?? from,
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: 'd',
  sourceId: source,
  sourceName: source == 'com.sec.android.app.shealth'
      ? 'Samsung Health'
      : source,
);

HealthDataPoint _workout(
  DateTime from,
  DateTime to, {
  HealthWorkoutActivityType type = HealthWorkoutActivityType.RUNNING,
  int? kcal = 320,
  int? meters = 5000,
  HealthDataUnit distanceUnit = HealthDataUnit.METER,
  String source = 'com.sec.android.app.shealth',
}) => HealthDataPoint(
  uuid: 'w-${from.microsecondsSinceEpoch}-$source',
  value: WorkoutHealthValue(
    workoutActivityType: type,
    totalEnergyBurned: kcal,
    totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
    totalDistance: meters,
    totalDistanceUnit: distanceUnit,
  ),
  type: HealthDataType.WORKOUT,
  unit: HealthDataUnit.NO_UNIT,
  dateFrom: from,
  dateTo: to,
  sourcePlatform: HealthPlatformType.googleHealthConnect,
  sourceDeviceId: 'd',
  sourceId: source,
  sourceName: 'Samsung Health',
);

VitalsSummary _build(
  List<HealthDataPoint> points, {
  Map<DateTime, int> steps = const {},
  int days = 7,
}) => buildVitalsSummary(
  periodStart: DateTime(2026, 9, 1),
  periodEnd: DateTime(2026, 9, days, 23, 59),
  dayCount: days,
  stepsByDay: steps,
  points: points,
  readMetrics: {for (final m in VitalsMetric.values) m},
);

void main() {
  final d1 = DateTime(2026, 9, 1);

  group('heart rate', () {
    test('summarises min, average and max per day', () {
      final v = _build([
        _point(HealthDataType.HEART_RATE, 52, d1.add(const Duration(hours: 3))),
        _point(HealthDataType.HEART_RATE, 70, d1.add(const Duration(hours: 9))),
        _point(
          HealthDataType.HEART_RATE,
          130,
          d1.add(const Duration(hours: 18)),
        ),
      ]);
      final day = v.days.first;
      expect(day.minHr, 52);
      expect(day.maxHr, 130);
      expect(day.avgHr, 84);
      expect(v.days[1].avgHr, isNull, reason: 'no data is null, not zero');
    });

    test('drops sensor glitches', () {
      final v = _build([
        _point(HealthDataType.HEART_RATE, 0, d1),
        _point(
          HealthDataType.HEART_RATE,
          300,
          d1.add(const Duration(hours: 1)),
        ),
        _point(HealthDataType.HEART_RATE, 60, d1.add(const Duration(hours: 2))),
      ]);
      expect(v.days.first.minHr, 60);
      expect(v.days.first.maxHr, 60);
    });

    test('keeps recorded resting rate separate from samples', () {
      final v = _build([
        _point(HealthDataType.RESTING_HEART_RATE, 58, d1),
        _point(
          HealthDataType.RESTING_HEART_RATE,
          60,
          d1.add(const Duration(hours: 5)),
        ),
      ]);
      expect(v.days.first.restingHr, 59);
      expect(v.days.first.avgHr, isNull);
      expect(v.averageRestingHr, 59);
    });

    test('ignores points outside the period', () {
      final v = _build([
        _point(HealthDataType.HEART_RATE, 60, DateTime(2026, 8, 31, 23)),
        _point(HealthDataType.HEART_RATE, 60, DateTime(2026, 9, 9)),
      ]);
      expect(v.days.every((d) => d.avgHr == null), isTrue);
    });
  });

  group('hrv and oxygen', () {
    test('averages hrv and ignores non-positive values', () {
      final v = _build([
        _point(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, 40, d1),
        _point(
          HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
          60,
          d1.add(const Duration(hours: 4)),
        ),
        _point(
          HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
          0,
          d1.add(const Duration(hours: 5)),
        ),
      ]);
      expect(v.days.first.hrvMs, 50);
    });

    test('reads oxygen as a percentage, including 0–1 fractions', () {
      final v = _build([
        _point(HealthDataType.BLOOD_OXYGEN, 0.97, d1),
        _point(
          HealthDataType.BLOOD_OXYGEN,
          95,
          d1.add(const Duration(hours: 2)),
        ),
        _point(
          HealthDataType.BLOOD_OXYGEN,
          12,
          d1.add(const Duration(hours: 3)),
        ),
      ]);
      expect(v.days.first.spo2Avg, closeTo(96, 0.01));
      expect(v.days.first.spo2Min, closeTo(95, 0.01));
    });
  });

  group('additive metrics', () {
    test('uses the single busiest source so apps are not double counted', () {
      final v = _build([
        _point(HealthDataType.ACTIVE_ENERGY_BURNED, 200, d1, source: 'a'),
        _point(
          HealthDataType.ACTIVE_ENERGY_BURNED,
          150,
          d1.add(const Duration(hours: 1)),
          source: 'a',
        ),
        _point(
          HealthDataType.ACTIVE_ENERGY_BURNED,
          340,
          d1.add(const Duration(hours: 2)),
          source: 'b',
        ),
      ]);
      expect(v.days.first.activeKcal, 350);
    });

    test('sums distance per day', () {
      final v = _build([
        _point(HealthDataType.DISTANCE_DELTA, 1200, d1, source: 'a'),
        _point(
          HealthDataType.DISTANCE_DELTA,
          800,
          d1.add(const Duration(hours: 1)),
          source: 'a',
        ),
      ]);
      expect(v.days.first.distanceMeters, 2000);
      expect(v.totalDistanceKm, 2);
    });
  });

  group('steps', () {
    test('keeps zero distinct from missing', () {
      final v = _build(const [], steps: {d1: 0, DateTime(2026, 9, 2): 8000});
      expect(v.days[0].steps, 0);
      expect(v.days[2].steps, isNull);
      expect(v.stepDays, hasLength(2));
      expect(v.averageSteps, 4000);
      expect(v.totalSteps, 8000);
      expect(v.bestStepDay!.date, DateTime(2026, 9, 2));
      expect(v.daysWithSteps(5000), 1);
    });
  });

  group('workouts', () {
    test('reads type, duration, energy and distance', () {
      final v = _build([
        _workout(
          d1.add(const Duration(hours: 7)),
          d1.add(const Duration(hours: 7, minutes: 40)),
        ),
      ]);
      final w = v.workouts.single;
      expect(w.label, 'Running');
      expect(w.duration, const Duration(minutes: 40));
      expect(w.kcal, 320);
      expect(w.distanceMeters, 5000);
      expect(v.workoutDays, 1);
      expect(v.sources[VitalsMetric.workouts], {'Samsung Health'});
    });

    test('collapses the same session written by two apps', () {
      final start = d1.add(const Duration(hours: 7));
      final v = _build([
        _workout(start, start.add(const Duration(minutes: 30))),
        _workout(
          start,
          start.add(const Duration(minutes: 30)),
          source: 'other.app',
        ),
      ]);
      expect(v.workouts, hasLength(1));
    });

    test('converts miles to metres', () {
      final start = d1.add(const Duration(hours: 7));
      final v = _build([
        _workout(
          start,
          start.add(const Duration(minutes: 30)),
          meters: 3,
          distanceUnit: HealthDataUnit.MILE,
        ),
      ]);
      expect(v.workouts.single.distanceMeters, closeTo(4828.03, 0.01));
    });

    test('skips zero-length sessions and prettifies names', () {
      final start = d1.add(const Duration(hours: 7));
      final v = _build([
        _workout(start, start),
        _workout(
          start.add(const Duration(days: 1)),
          start.add(const Duration(days: 1, hours: 1)),
          type: HealthWorkoutActivityType.STRENGTH_TRAINING,
        ),
      ]);
      expect(v.workouts, hasLength(1));
      expect(v.workouts.single.label, 'Strength training');
    });

    test('totals by type, longest first', () {
      final a = d1.add(const Duration(hours: 7));
      final b = d1.add(const Duration(days: 1, hours: 7));
      final c = d1.add(const Duration(days: 2, hours: 7));
      final v = _build([
        _workout(a, a.add(const Duration(minutes: 30))),
        _workout(b, b.add(const Duration(minutes: 30))),
        _workout(
          c,
          c.add(const Duration(minutes: 90)),
          type: HealthWorkoutActivityType.BIKING,
          kcal: null,
        ),
      ]);
      final totals = v.workoutsByType;
      expect(totals.first.label, 'Biking');
      expect(totals.first.kcal, isNull);
      expect(totals.last.count, 2);
      expect(totals.last.kcal, 640);
      expect(v.totalWorkoutTime, const Duration(minutes: 150));
      expect(v.workoutDays, 3);
    });
  });

  group('weight', () {
    test('keeps the period plus the last reading before it as baseline', () {
      final v = _build([
        _point(HealthDataType.WEIGHT, 80.0, DateTime(2026, 7, 1)),
        _point(HealthDataType.WEIGHT, 79.0, DateTime(2026, 8, 20)),
        _point(HealthDataType.WEIGHT, 78.5, DateTime(2026, 9, 4)),
        _point(HealthDataType.WEIGHT, 78.0, DateTime(2026, 9, 6)),
      ]);
      expect(v.weights.map((w) => w.kg), [79.0, 78.5, 78.0]);
      expect(v.latestWeight!.kg, 78.0);
      expect(v.weightChangeKg, closeTo(-1.0, 1e-9));
    });

    test('rejects implausible weights and needs two readings for a change', () {
      final v = _build([
        _point(HealthDataType.WEIGHT, 5, DateTime(2026, 9, 3)),
        _point(HealthDataType.WEIGHT, 77.0, DateTime(2026, 9, 4)),
      ]);
      expect(v.weights, hasLength(1));
      expect(v.weightChangeKg, isNull);
    });
  });

  group('summary', () {
    test('is empty when nothing was read', () {
      final v = _build(const []);
      expect(v.hasData, isFalse);
      expect(v.days, hasLength(7));
      expect(v.averageSteps, isNull);
      expect(v.averageRestingHr, isNull);
      expect(v.peakHr, isNull);
    });

    test('reports which apps wrote each metric', () {
      final v = _build([_point(HealthDataType.HEART_RATE, 60, d1)]);
      expect(v.sources[VitalsMetric.heartRate], {'Samsung Health'});
    });

    test('survives a JSON round trip', () {
      final start = d1.add(const Duration(hours: 7));
      final v = _build(
        [
          _point(HealthDataType.HEART_RATE, 60, d1),
          _point(HealthDataType.WEIGHT, 78.0, DateTime(2026, 9, 4)),
          _workout(start, start.add(const Duration(minutes: 30))),
        ],
        steps: {d1: 4321},
      );
      final back = VitalsSummary.fromJson(v.toJson());
      expect(back.days, hasLength(7));
      expect(back.days.first.steps, 4321);
      expect(back.days.first.avgHr, 60);
      expect(back.workouts.single.label, 'Running');
      expect(back.latestWeight!.kg, 78.0);
      expect(back.readMetrics, v.readMetrics);
      expect(back.sources[VitalsMetric.heartRate], {'Samsung Health'});
    });
  });
}
