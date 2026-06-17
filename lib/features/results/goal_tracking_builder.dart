import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/location/timeline_activity.dart';

class GoalTrackingInput {
  const GoalTrackingInput({
    this.currentLocation,
    this.previousLocation,
    this.currentGameActivity,
    this.previousGameActivity,
  });

  final LocationSummary? currentLocation;
  final LocationSummary? previousLocation;
  final GameActivitySummary? currentGameActivity;
  final GameActivitySummary? previousGameActivity;
}

String buildGoalTrackingText(GoalTrackingInput input) {
  final sections = <String>[];

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
    ..writeln('Distance:')
    ..writeln('- Current: ${currentDistanceKm.toStringAsFixed(2)} km');

  final previousTrips = previous == null || !previous.hasAnyData
      ? <TimelineActivity>[]
      : previous.periodMotorcyclingActivities
          .where((trip) => trip.distanceMeters > 0)
          .toList();

  if (previousTrips.isNotEmpty) {
    final previousDistanceKm = previousTrips.fold<double>(
          0,
          (sum, trip) => sum + trip.distanceMeters,
        ) /
        1000;
    final distanceChange = currentDistanceKm - previousDistanceKm;
    buffer
      ..writeln('- Previous: ${previousDistanceKm.toStringAsFixed(2)} km')
      ..writeln(
        '- Change: ${distanceChange >= 0 ? '+' : ''}${distanceChange.toStringAsFixed(2)} km',
      );
  }

  buffer
    ..writeln()
    ..writeln('Sessions:')
    ..writeln('- Current: ${currentTrips.length}');

  if (previousTrips.isNotEmpty) {
    final sessionChange = currentTrips.length - previousTrips.length;
    buffer
      ..writeln('- Previous: ${previousTrips.length}')
      ..writeln('- Change: ${sessionChange >= 0 ? '+' : ''}$sessionChange');
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
