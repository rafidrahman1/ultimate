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
  RecordingMethod recordingMethod = RecordingMethod.active,
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
    recordingMethod: recordingMethod,
  );
}

void main() {
  test('includes every workout in the analysis month', () {
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
      _workoutPoint(
        from: DateTime(2026, 5, 20, 7, 0),
        to: DateTime(2026, 5, 20, 8, 0),
        recordingMethod: RecordingMethod.automatic,
      ),
    ];

    final stats = MonthlyWorkoutStats.fromPoints(
      workouts,
      periodStart: DateTime(2026, 5, 1),
      periodEnd: DateTime(2026, 5, 31, 23, 59),
    );

    expect(stats.sessionCount, 3);
    expect(stats.totalDistanceKm, closeTo(11.7, 0.01));
    expect(stats.totalDuration, const Duration(hours: 2, minutes: 45));
  });

  test('combines two workouts on the same day into one session', () {
    final stats = MonthlyWorkoutStats.fromPoints(
      [
        _workoutPoint(
          from: DateTime(2026, 5, 20, 7, 0),
          to: DateTime(2026, 5, 20, 8, 0),
          distanceMeters: 5000,
          recordingMethod: RecordingMethod.automatic,
        ),
        _workoutPoint(
          from: DateTime(2026, 5, 20, 18, 0),
          to: DateTime(2026, 5, 20, 19, 0),
          distanceMeters: 3000,
          recordingMethod: RecordingMethod.automatic,
        ),
      ],
      periodStart: DateTime(2026, 5, 1),
      periodEnd: DateTime(2026, 5, 31, 23, 59),
    );

    expect(stats.sessionCount, 1);
    expect(stats.sessions.single.start, DateTime(2026, 5, 20, 7, 0));
    expect(stats.sessions.single.end, DateTime(2026, 5, 20, 19, 0));
    expect(stats.sessions.single.duration, const Duration(hours: 2));
    expect(stats.totalDistanceKm, closeTo(8, 0.01));
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
