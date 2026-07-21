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
  const GameActivitySummary({required this.sessions, this.fileName});

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

  static String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
