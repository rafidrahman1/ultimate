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
  String toAnalysisPromptText({GameActivitySummary? previous}) {
    if (sessions.isEmpty) {
      return 'No game activity data imported. '
          '(Note: Late night bedtimes indicate screen-time or lifestyle displacement).';
    }

    final buffer = StringBuffer('Gaming Summary');

    final trend = _gamingTrendText(previous: previous);
    if (trend != null) {
      buffer
        ..writeln()
        ..writeln()
        ..write(trend);
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

    buffer
      ..writeln()
      ..writeln(periodLine.trimRight())
      ..writeln(
        'Total play time: ${formatPromptDuration(totalPlayTime)} '
        'across $uniqueGameCount games (${sessions.length} sessions)',
      )
      ..writeln('Time by game:')
      ..writeln(totalsLines)
      ..writeln('Sessions:')
      ..writeln(sessionLines.join('\n'));

    return buffer.toString().trimRight();
  }

  String? _gamingTrendText({GameActivitySummary? previous}) {
    final currentSessions = sessions.length;
    final currentHours = totalPlayTime.inMinutes / 60;

    final buffer = StringBuffer('Gaming Trend:')
      ..writeln()
      ..writeln('- Current sessions: $currentSessions')
      ..writeln(
        '- Current play time: ${formatPromptDuration(totalPlayTime)}',
      );

    if (previous == null || previous.sessions.isEmpty) {
      buffer.writeln('- Previous sessions: not available');
      return buffer.toString().trimRight();
    }

    final previousSessions = previous.sessions.length;
    final sessionChange = currentSessions - previousSessions;
    final hoursChange = currentHours - previous.totalPlayTime.inMinutes / 60;
    final trend = sessionChange == 0
        ? 'Stable'
        : sessionChange > 0
        ? 'Increasing'
        : 'Declining';

    buffer
      ..writeln('- Previous sessions: $previousSessions')
      ..writeln(
        '- Change: ${sessionChange >= 0 ? '+' : ''}$sessionChange sessions',
      )
      ..writeln(
        '- Play time change: ${hoursChange >= 0 ? '+' : ''}${hoursChange.toStringAsFixed(1)}h',
      )
      ..writeln('- Trend: $trend');

    return buffer.toString().trimRight();
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
