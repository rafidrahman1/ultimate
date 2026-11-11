import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/game_activity/data/game_activity_csv_parser.dart';
import 'package:personal/features/game_activity/data/game_activity_session.dart';

void main() {
  test('parses every duration format and skips bad rows', () {
    final sessions = parseGameActivityCsv(
      '﻿Name;Date session;Time Played\r\n'
      'Hades;2026-11-01 20:00:00.000;01:30:15\r\n'
      'Celeste;2026-11-02 21:00:00;45:10\r\n'
      'Tetris;2026-11-03 08:00:00;4627\r\n'
      ';2026-11-03 08:00:00;10\r\n'
      'NoDate;;10\r\n'
      'BadTime;2026-11-03 08:00:00;soon\r\n'
      ';;\r\n',
    );
    expect(sessions.map((s) => s.name), ['Hades', 'Celeste', 'Tetris']);
    expect(
      sessions[0].timePlayed,
      const Duration(hours: 1, minutes: 30, seconds: 15),
    );
    expect(sessions[0].sessionDate, DateTime(2026, 11, 1, 20));
    expect(sessions[1].timePlayed, const Duration(minutes: 45, seconds: 10));
    expect(sessions[2].timePlayed, const Duration(seconds: 4627));
  });

  test('column order and header case do not matter', () {
    final sessions = parseGameActivityCsv(
      'time played;NAME;extra;date session\n30;Hades;x;2026-11-01 20:00:00\n',
    );
    expect(sessions.single.name, 'Hades');
    expect(sessions.single.timePlayed, const Duration(seconds: 30));
  });

  test('empty input gives no sessions; a wrong header throws', () {
    expect(parseGameActivityCsv(''), isEmpty);
    expect(() => parseGameActivityCsv('a;b;c\n1;2;3'), throwsFormatException);
  });

  test('summary totals', () {
    final summary = GameActivitySummary(
      sessions: [
        GameActivitySession(
          name: 'A',
          sessionDate: DateTime(2026, 11, 1),
          timePlayed: const Duration(minutes: 30),
        ),
        GameActivitySession(
          name: 'A',
          sessionDate: DateTime(2026, 11, 3),
          timePlayed: const Duration(minutes: 45),
        ),
        GameActivitySession(
          name: 'B',
          sessionDate: DateTime(2026, 11, 2),
          timePlayed: const Duration(minutes: 15),
        ),
      ],
    );
    expect(summary.totalPlayTime, const Duration(minutes: 90));
    expect(summary.uniqueGameCount, 2);
    expect(summary.sortedByDate.first.sessionDate, DateTime(2026, 11, 3));
  });
}
