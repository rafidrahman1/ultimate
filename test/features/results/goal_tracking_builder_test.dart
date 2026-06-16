import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/results/goal_tracking_builder.dart';

TimelineActivity _cyclingTrip({
  required DateTime start,
  required double distanceMeters,
}) {
  return TimelineActivity(
    startTime: start,
    endTime: start.add(const Duration(hours: 1)),
    type: 'MOTORCYCLING',
    distanceMeters: distanceMeters,
  );
}

void main() {
  test('separates cycling distance and session changes', () {
    final text = buildGoalTrackingText(
      GoalTrackingInput(
        currentLocation: LocationSummary(
          activities: [
            for (var i = 0; i < 55; i++)
              _cyclingTrip(
                start: DateTime(2026, 5, 1 + i),
                distanceMeters: 8700,
              ),
          ],
          placeVisits: const [],
        ),
        previousLocation: LocationSummary(
          activities: [
            for (var i = 0; i < 59; i++)
              _cyclingTrip(
                start: DateTime(2026, 4, 1 + i),
                distanceMeters: 8333,
              ),
          ],
          placeVisits: const [],
        ),
      ),
    );

    expect(text, contains('Distance:'));
    expect(text, contains('- Current: 478.50 km'));
    expect(text, contains('- Previous: 491.65 km'));
    expect(text, contains('- Change: -13.15 km'));
    expect(text, contains('Sessions:'));
    expect(text, contains('- Current: 55'));
    expect(text, contains('- Previous: 59'));
    expect(text, contains('- Change: -4'));
    expect(text, isNot(contains('Sleep:')));
  });

  test('includes exercise sessions without sleep metrics', () {
    final text = buildGoalTrackingText(
      GoalTrackingInput(
        currentGameActivity: GameActivitySummary(
          sessions: [
            GameActivitySession(
              name: 'Ring Fit',
              sessionDate: DateTime(2026, 5, 1),
              timePlayed: const Duration(hours: 1),
            ),
          ],
        ),
        previousGameActivity: GameActivitySummary(
          sessions: [
            GameActivitySession(
              name: 'Ring Fit',
              sessionDate: DateTime(2026, 4, 1),
              timePlayed: const Duration(hours: 1),
            ),
            GameActivitySession(
              name: 'Ring Fit',
              sessionDate: DateTime(2026, 4, 2),
              timePlayed: const Duration(hours: 1),
            ),
          ],
        ),
      ),
    );

    expect(text, contains('Exercise:'));
    expect(text, contains('- Sessions: 1'));
    expect(text, contains('- Previous sessions: 2'));
    expect(text, contains('- Change: -1'));
  });
}
