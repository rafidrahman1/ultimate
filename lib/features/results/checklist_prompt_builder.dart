import 'package:intl/intl.dart';

import '../../core/analysis_period.dart';
import 'insights_models.dart';

/// Builds the checklist block injected into progress-review prompts.
String buildChecklistTargetsPromptBlock({
  required InsightsParsedReport report,
  required AnalysisPeriod checklistPeriod,
  required Map<int, Set<int>> completionByWeek,
  required String sourceResultTitle,
  required DateTime sourceGeneratedAt,
}) {
  final buffer = StringBuffer();
  final generated = DateFormat('d MMM yyyy · HH:mm')
      .format(sourceGeneratedAt.toLocal());

  buffer.writeln('Report: $sourceResultTitle');
  buffer.writeln('Generated: $generated');
  buffer.writeln('Target month: ${checklistPeriod.checklistMonthLabel}');
  buffer.writeln();

  final weekCount = report.checklistWeekCount;
  for (var weekIndex = 0; weekIndex < weekCount; weekIndex++) {
    final actions = report.actionsForWeekIndex(weekIndex);
    if (actions.isEmpty) continue;

    final weekLabel = weekIndex < checklistPeriod.checklistWeeks.length
        ? 'Week ${checklistPeriod.checklistWeeks[weekIndex].weekNumber} · '
            '${checklistPeriod.checklistWeeks[weekIndex].isoRangeLabel}'
        : 'Week ${weekIndex + 1}';

    buffer.writeln('##### $weekLabel');
    final done = completionByWeek[weekIndex] ?? {};
    for (var actionIndex = 0; actionIndex < actions.length; actionIndex++) {
      final action = actions[actionIndex];
      final mark = done.contains(actionIndex) ? '[x]' : '[ ]';
      final group = action.groupLabel == null ? '' : ' (${action.groupLabel})';
      buffer.writeln(
        '$mark **${action.title}**$group: ${action.description}'.trim(),
      );
    }
    buffer.writeln();
  }

  if (report.actions.isEmpty) {
    buffer.writeln('(No structured checklist actions found in source report.)');
  }

  return buffer.toString().trimRight();
}

/// One-line adherence summary for the progress-review prompt.
String buildChecklistCompletionSummary({
  required InsightsParsedReport report,
  required Map<int, Set<int>> completionByWeek,
}) {
  var total = 0;
  var done = 0;

  for (var weekIndex = 0; weekIndex < report.checklistWeekCount; weekIndex++) {
    final actions = report.actionsForWeekIndex(weekIndex);
    total += actions.length;
    done += (completionByWeek[weekIndex] ?? {}).length;
  }

  if (total == 0) return 'No checklist actions to score.';
  final pct = ((done / total) * 100).round();
  return '$done of $total actions marked complete ($pct%)';
}
