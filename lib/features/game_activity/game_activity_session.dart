import 'package:personal/features/analysis/analysis_period.dart';

class GameActivitySession {
  const GameActivitySession({
    required this.name,
    required this.sessionDate,
    required this.timePlayed,
  });

  final String name;
  final DateTime sessionDate;
  final Duration timePlayed;
}

class GameActivitySummary {
  const GameActivitySummary({
    required this.sessions,
    this.fileName,
  });

  final List<GameActivitySession> sessions;
  final String? fileName;

  GameActivitySummary forAnalysisPeriod(AnalysisPeriod period) {
    final filtered = sessions
        .where(
          (s) => isDateInRange(
            s.sessionDate,
            period.dataMonthStart,
            period.dataMonthEnd,
          ),
        )
        .toList();
    return GameActivitySummary(sessions: filtered, fileName: fileName);
  }

  List<GameActivitySession> get sortedByDate {
    final copy = List<GameActivitySession>.from(sessions);
    copy.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    return copy;
  }

  Duration get totalPlayTime {
    return sessions.fold(
      Duration.zero,
      (total, session) => total + session.timePlayed,
    );
  }

  int get uniqueGameCount {
    return sessions.map((session) => session.name).toSet().length;
  }

  String? get periodRangeLabel {
    if (sessions.isEmpty) return null;
    final dates = sessions.map((s) => s.sessionDate.toLocal()).toList()
      ..sort((a, b) => a.compareTo(b));
    final start = dates.first;
    final end = dates.last;
    final startLabel = _dateKey(start);
    final endLabel = _dateKey(end);
    if (startLabel == endLabel) return startLabel;
    return '$startLabel to $endLabel';
  }

  /// Line items for AI analysis; one dated line per gaming session.
  String toAnalysisPromptText() {
    if (sessions.isEmpty) {
      return 'No game activity data imported. '
          '(Note: Late night bedtimes indicate screen-time or lifestyle displacement).';
    }

    final period = periodRangeLabel;
    final periodLine =
        period != null ? 'Period: $period\n' : 'Period: unknown\n';

    final byGame = <String, Duration>{};
    for (final session in sessions) {
      byGame[session.name] =
          (byGame[session.name] ?? Duration.zero) + session.timePlayed;
    }
    final gameTotals = byGame.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalsLines = gameTotals
        .map(
          (entry) =>
              '  - ${entry.key}: ${formatPromptDuration(entry.value)}',
        )
        .join('\n');

    final sorted = sortedByDate;
    final sessionLines = <String>[];
    String? lastDate;
    for (final session in sorted) {
      final date = _dateKey(session.sessionDate);
      final showDate = date != lastDate;
      lastDate = date;
      final duration = formatPromptDuration(session.timePlayed);
      if (showDate) {
        sessionLines.add('  - $date · ${session.name}: $duration');
      } else {
        sessionLines.add('  - ${session.name}: $duration');
      }
    }

    return '$periodLine'
        'Total play time: ${formatPromptDuration(totalPlayTime)} '
        'across $uniqueGameCount games (${sessions.length} sessions)\n'
        'Time by game:\n$totalsLines\n'
        'Sessions:\n${sessionLines.join('\n')}';
  }

  static String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String formatPromptDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}
