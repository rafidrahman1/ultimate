import 'package:intl/intl.dart';

import 'package:personal/features/screen_time/data/screen_time_models.dart';

String _dur(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h == 0 ? '${m}m' : '${h}h ${m.toString().padLeft(2, '0')}m';
}

extension ScreenTimePromptText on ScreenTimeSummary {
  /// Per-day and per-app phone usage as plain text for exports and prompts.
  String toAnalysisPromptText({ScreenTimeSummary? previous}) {
    if (isEmpty) return 'No screen time data available.';
    final days = byDay;
    final out = StringBuffer('Screen Time (Digital Wellbeing usage stats)\n')
      ..writeln(
        '- ${days.length} days tracked, ${_dur(total)} in total, '
        '${_dur(averagePerActiveDay)} per day on average',
      );
    if (previous != null && !previous.isEmpty) {
      final change =
          averagePerActiveDay.inMinutes -
          previous.averagePerActiveDay.inMinutes;
      out.writeln(
        '- Previous period averaged ${_dur(previous.averagePerActiveDay)} '
        'per day (${change >= 0 ? '+' : '-'}${_dur(Duration(minutes: change.abs()))} '
        'per day now)',
      );
    }
    out.writeln('\nTop apps:');
    for (final app in topApps.take(8)) {
      out.writeln('  - ${app.label}: ${_dur(app.duration)}');
    }
    out.writeln('\nPer day:');
    final keys = days.keys.toList()..sort();
    final fmt = DateFormat('yyyy-MM-dd (EEE)');
    for (final day in keys) {
      out.writeln('  - ${fmt.format(day)}: ${_dur(days[day]!)}');
    }
    return out.toString().trimRight();
  }
}
