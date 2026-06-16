import 'package:personal/features/analysis/period_comparison.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_prompt_builder.dart';
import 'package:personal/features/location/timeline_activity.dart';

class GoalTrackingInput {
  const GoalTrackingInput({
    this.currentHealth,
    this.previousHealth,
    this.currentLocation,
    this.previousLocation,
    this.currentGameActivity,
    this.previousGameActivity,
  });

  final MonthlyHealthSummary? currentHealth;
  final MonthlyHealthSummary? previousHealth;
  final LocationSummary? currentLocation;
  final LocationSummary? previousLocation;
  final GameActivitySummary? currentGameActivity;
  final GameActivitySummary? previousGameActivity;
}

String buildGoalTrackingText(GoalTrackingInput input) {
  final sections = <String>[];

  final sleepSection = _sleepGoalSection(
    current: input.currentHealth,
    previous: input.previousHealth,
  );
  if (sleepSection != null) sections.add(sleepSection);

  final cyclingSection = _cyclingGoalSection(
    current: input.currentLocation,
    previous: input.previousLocation,
  );
  if (cyclingSection != null) sections.add(cyclingSection);

  final exerciseSection = _exerciseGoalSection(
    current: input.currentGameActivity,
    previous: input.previousGameActivity,
  );
  if (exerciseSection != null) sections.add(exerciseSection);

  if (sections.isEmpty) return '';

  return 'Goal Tracking:\n\n${sections.join('\n\n')}';
}

String? _sleepGoalSection({
  MonthlyHealthSummary? current,
  MonthlyHealthSummary? previous,
}) {
  final currentAvg = current == null
      ? null
      : averageSleepDuration(
          current.dailySleep.where((night) => night.hasData).toList(),
        );
  if (currentAvg == null) return null;

  final previousAvg = previous == null
      ? null
      : averageSleepDuration(
          previous.dailySleep.where((night) => night.hasData).toList(),
        );

  final buffer = StringBuffer('Sleep:')
    ..writeln()
    ..writeln('- Current: ${formatDurationPadded(currentAvg)}');

  if (previousAvg != null) {
    final change = Duration(
      minutes: currentAvg.inMinutes - previousAvg.inMinutes,
    );
    buffer
      ..writeln('- Previous: ${formatDurationPadded(previousAvg)}')
      ..writeln('- Change: ${formatSignedDurationChange(change)}');
  }

  return buffer.toString().trimRight();
}

String? _cyclingGoalSection({
  LocationSummary? current,
  LocationSummary? previous,
}) {
  if (current == null || !current.hasAnyData) return null;

  final currentTrips = current.periodMotorcyclingActivities
      .where((trip) => trip.distanceMeters > 0)
      .toList();
  if (currentTrips.isEmpty) return null;

  final currentDistanceKm = currentTrips.fold<double>(
        0,
        (sum, trip) => sum + trip.distanceMeters,
      ) /
      1000;

  final buffer = StringBuffer('Cycling:')
    ..writeln()
    ..writeln('- Sessions: ${currentTrips.length}')
    ..writeln('- Distance: ${currentDistanceKm.toStringAsFixed(2)} km');

  if (previous != null && previous.hasAnyData) {
    final previousTrips = previous.periodMotorcyclingActivities
        .where((trip) => trip.distanceMeters > 0)
        .toList();
    if (previousTrips.isNotEmpty) {
      final previousDistanceKm = previousTrips.fold<double>(
            0,
            (sum, trip) => sum + trip.distanceMeters,
          ) /
          1000;
      final change = currentDistanceKm - previousDistanceKm;
      buffer
        ..writeln('- Previous sessions: ${previousTrips.length}')
        ..writeln(
          '- Change: ${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)} km',
        );
    }
  }

  return buffer.toString().trimRight();
}

String? _exerciseGoalSection({
  GameActivitySummary? current,
  GameActivitySummary? previous,
}) {
  if (current == null || current.sessions.isEmpty) return null;

  final buffer = StringBuffer('Exercise:')
    ..writeln()
    ..writeln('- Sessions: ${current.sessions.length}');

  if (previous != null && previous.sessions.isNotEmpty) {
    final change = current.sessions.length - previous.sessions.length;
    buffer
      ..writeln('- Previous sessions: ${previous.sessions.length}')
      ..writeln('- Change: ${change >= 0 ? '+' : ''}$change');
  }

  return buffer.toString().trimRight();
}
