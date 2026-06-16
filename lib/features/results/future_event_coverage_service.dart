import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/results/checklist_week_markdown.dart';
import 'package:personal/features/results/future_event_coverage_validator.dart';
import 'package:personal/features/results/future_event_week_regeneration_prompt.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

const int maxFutureEventCoverageRounds = 5;

class FutureEventCoverageFailure implements Exception {
  FutureEventCoverageFailure(this.missing);

  final List<FutureEventCoverageMiss> missing;

  @override
  String toString() {
    final labels = missing
        .map((miss) => '${miss.eventTitle} (week ${miss.weekNumber})')
        .join(', ');
    return 'Future event coverage incomplete after $maxFutureEventCoverageRounds '
        'attempts: $labels';
  }
}

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
  }) generate,
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
    for (final weekNumber in weeksToFix) {
      final sections = parseChecklistWeekSections(current);
      final section = checklistWeekSectionForNumber(sections, weekNumber);
      final currentWeekMarkdown = section?.markdown ?? '';
      final missingForWeek =
          missing.where((miss) => miss.weekNumber == weekNumber).toList();
      final weekFutureEvents = assignments
          .where((assignment) => assignment.weekNumber == weekNumber)
          .map((assignment) => assignment.event)
          .toList();

      final regenPrompt = buildFutureEventWeekRegenerationPrompt(
        period: period,
        weekNumber: weekNumber,
        missingForWeek: missingForWeek,
        weekFutureEvents: weekFutureEvents,
        currentWeekMarkdown: currentWeekMarkdown,
        selection: selection,
      );

      final regenerated = await generate(
        settings: aiSettings,
        prompt: regenPrompt,
        systemInstruction: systemInstruction,
      );

      current = replaceChecklistWeekSection(
        current,
        weekNumber,
        regenerated,
      );
    }
  }

  final remaining = findMissingFutureEventCoverage(
    markdown: current,
    assignments: assignments,
  );
  if (remaining.isNotEmpty) {
    throw FutureEventCoverageFailure(remaining);
  }
  return current;
}
