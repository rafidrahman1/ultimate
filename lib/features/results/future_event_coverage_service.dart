import 'package:personal/core/app_log.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/results/checklist_week_markdown.dart';
import 'package:personal/features/results/future_event_coverage_validator.dart';
import 'package:personal/features/results/future_event_week_regeneration_prompt.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

/// Each round re-asks the model for every week still missing an upcoming
/// event, in parallel. Two rounds keeps a run to at most two extra
/// round-trips; anything still missing after that is left as-is rather than
/// discarding an otherwise good report.
const int maxFutureEventCoverageRounds = 2;

Future<String> ensureFutureEventCoverageInOutput({
  required String output,
  required AnalysisPeriod period,
  required CalendarSummary calendarUpcoming,
  required AnalysisSourceSelection selection,
  required PromptConfig config,
  required AiSettings aiSettings,
  required Future<String> Function({
    required AiSettings settings,
    required String prompt,
    required String systemInstruction,
  })
  generate,
}) async {
  if (!selection.includes(AnalysisDataSourceId.calendar)) return output;

  final futureEvents = parseFutureEventsFromSource(
    upcomingSource: calendarUpcoming,
    after: period.dataMonthEnd,
  );
  if (futureEvents.isEmpty) return output;

  final assignments = assignFutureEventsToChecklistWeeks(
    futureEvents: futureEvents,
    period: period,
  );
  if (assignments.isEmpty) return output;

  var current = output;
  final systemInstruction = config.composeSystemInstruction();

  for (var round = 0; round < maxFutureEventCoverageRounds; round++) {
    final missing = findMissingFutureEventCoverage(
      markdown: current,
      assignments: assignments,
    );
    if (missing.isEmpty) return current;

    final weeksToFix = missing.map((miss) => miss.weekNumber).toSet().toList()
      ..sort();
    final sections = parseChecklistWeekSections(current);
    final regenerated = await Future.wait([
      for (final weekNumber in weeksToFix)
        generate(
          settings: aiSettings,
          prompt: buildFutureEventWeekRegenerationPrompt(
            period: period,
            weekNumber: weekNumber,
            missingForWeek: missing
                .where((miss) => miss.weekNumber == weekNumber)
                .toList(),
            weekFutureEvents: assignments
                .where((assignment) => assignment.weekNumber == weekNumber)
                .map((assignment) => assignment.event)
                .toList(),
            currentWeekMarkdown:
                checklistWeekSectionForNumber(sections, weekNumber)?.markdown ??
                '',
            selection: selection,
          ),
          systemInstruction: systemInstruction,
        ),
    ]);
    for (var i = 0; i < weeksToFix.length; i++) {
      current = replaceChecklistWeekSection(
        current,
        weeksToFix[i],
        regenerated[i],
      );
    }
  }

  final remaining = findMissingFutureEventCoverage(
    markdown: current,
    assignments: assignments,
  );
  if (remaining.isNotEmpty) {
    AppLog.warn(
      'Calendar coverage still missing after '
      '$maxFutureEventCoverageRounds rounds: '
      '${remaining.map((miss) => miss.eventTitle).join(', ')}',
    );
  }
  return current;
}
