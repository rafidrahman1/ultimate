import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';

void main() {
  test('toAnalysisPromptText summarizes sessions for analysis', () {
    final summary = GameActivitySummary(
      sessions: [
        GameActivitySession(
          name: 'Valorant',
          sessionDate: DateTime(2026, 5, 30, 1, 44, 55),
          timePlayed: const Duration(seconds: 36),
        ),
        GameActivitySession(
          name: 'PEAK',
          sessionDate: DateTime(2026, 5, 30, 1, 48, 57),
          timePlayed: const Duration(seconds: 56),
        ),
      ],
    );

    final text = summary.toAnalysisPromptText();

    expect(text, contains('Period: 2026-05-30'));
    expect(text, contains('Valorant'));
    expect(text, contains('PEAK'));
    expect(text, contains('Time by game:'));
    expect(text, contains('Sessions:'));
  });
}
