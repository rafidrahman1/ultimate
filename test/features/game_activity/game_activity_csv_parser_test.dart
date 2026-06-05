import 'package:flutter_test/flutter_test.dart';

import 'package:Personal/features/game_activity/game_activity_csv_parser.dart';

void main() {
  group('parseGameActivityCsv', () {
    test('parses semicolon-delimited export with HH:MM:SS durations', () {
      const content =
          'Name;Date session;Time Played\n'
          'Valorant;2026-05-30 01:44:55;00:00:36\n'
          'AimLabs;2026-05-29 18:12:14;00:00:22';

      final sessions = parseGameActivityCsv(content);

      expect(sessions, hasLength(2));
      expect(sessions.first.name, 'Valorant');
      expect(sessions.first.timePlayed, const Duration(seconds: 36));
      expect(sessions.last.name, 'AimLabs');
    });

    test('parses durations as total seconds (newer phone export)', () {
      const content =
          'Name;Date session;Time Played\n'
          'Valorant;2026-05-30 01:44:55;36\n'
          'Valorant;2026-05-30 11:24:21;4627\n'
          'AimLabs;2026-05-29 18:12:14;22';

      final sessions = parseGameActivityCsv(content);

      expect(sessions, hasLength(3));
      expect(sessions.first.timePlayed, const Duration(seconds: 36));
      expect(sessions[1].timePlayed, const Duration(seconds: 4627));
      expect(sessions.last.timePlayed, const Duration(seconds: 22));
    });
  });
}
