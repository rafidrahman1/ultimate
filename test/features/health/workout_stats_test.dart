import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/workout_stats.dart';

HealthDataPoint _workoutPoint({
  required DateTime from,
  required DateTime to,
  HealthWorkoutActivityType type = HealthWorkoutActivityType.RUNNING,
  int? distanceMeters,
  String sourceName = 'com.sec.android.app.shealth',
}) {
  return HealthDataPoint(
    uuid: 'workout-$from-$to',
    value: WorkoutHealthValue(
      workoutActivityType: type,
      totalDistance: distanceMeters,
      totalDistanceUnit: HealthDataUnit.METER,
    ),
    type: HealthDataType.WORKOUT,
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
  test('dedupes overlapping Samsung and non-Samsung workout mirrors', () {
    final samsung = _workoutPoint(
      from: DateTime(2026, 5, 20, 7, 0),
      to: DateTime(2026, 5, 20, 8, 0),
      distanceMeters: 5000,
    );
    final mirror = _workoutPoint(
      from: DateTime(2026, 5, 20, 7, 5),
      to: DateTime(2026, 5, 20, 7, 55),
      distanceMeters: 4800,
      sourceName: 'com.google.android.apps.fitness',
    );

    final stats = MonthlyWorkoutStats.fromPoints(
      [samsung, mirror],
      periodStart: DateTime(2026, 5, 1),
      periodEnd: DateTime(2026, 5, 31, 23, 59),
    );

    expect(stats.sessionCount, 1);
    expect(stats.totalDistanceKm, closeTo(5, 0.01));
    expect(stats.totalDuration, const Duration(hours: 1));
  });

  test('sums distinct workouts in the analysis month', () {
    final workouts = [
      _workoutPoint(
        from: DateTime(2026, 5, 10, 18, 0),
        to: DateTime(2026, 5, 10, 19, 15),
        type: HealthWorkoutActivityType.WALKING,
        distanceMeters: 3200,
      ),
      _workoutPoint(
        from: DateTime(2026, 5, 12, 6, 30),
        to: DateTime(2026, 5, 12, 7, 0),
        type: HealthWorkoutActivityType.BIKING,
        distanceMeters: 8500,
      ),
    ];

    final stats = MonthlyWorkoutStats.fromPoints(
      workouts,
      periodStart: DateTime(2026, 5, 1),
      periodEnd: DateTime(2026, 5, 31, 23, 59),
    );

    expect(stats.sessionCount, 2);
    expect(stats.totalDistanceKm, closeTo(11.7, 0.01));
    expect(stats.totalDuration, const Duration(hours: 1, minutes: 45));
    expect(stats.sessions.first.activityLabel, 'Biking');
  });

  test('monthly summary includes workout stats in analysis prompt', () {
    final fetch = MonthlyHealthFetchResult(
      points: [
        _workoutPoint(
          from: DateTime(2026, 5, 20, 7, 0),
          to: DateTime(2026, 5, 20, 8, 0),
          distanceMeters: 5000,
        ),
      ],
      periodStart: DateTime(2026, 5, 1),
      periodEnd: DateTime(2026, 5, 31, 23, 59),
      dailySteps: const {},
      dayCount: 31,
    );

    final summary = MonthlyHealthSummary.fromFetch(fetch);
    final text = summary.toAnalysisPromptText();

    expect(summary.workoutStats.sessionCount, 1);
    expect(text, contains('Workouts: 1 sessions, 5.0 km total, 1h 0m total'));
  });
}
