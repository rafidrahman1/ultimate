import 'package:intl/intl.dart';

import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/results/analysis_checklist_builder.dart';
import 'package:personal/features/results/future_event_coverage_validator.dart';

String buildFutureEventWeekRegenerationPrompt({
  required AnalysisPeriod period,
  required int weekNumber,
  required List<FutureEventCoverageMiss> missingForWeek,
  required List<CalendarPromptEvent> weekFutureEvents,
  required String currentWeekMarkdown,
  required AnalysisSourceSelection selection,
}) {
  final week = period.checklistWeeks.firstWhere(
    (segment) => segment.weekNumber == weekNumber,
    orElse: () => period.checklistWeeks.first,
  );
  final weekHeader = 'Week ${week.weekNumber} · ${week.isoRangeLabel}';
  final missingTitles = missingForWeek
      .map((miss) => miss.eventTitle)
      .toSet()
      .map((title) => '- $title')
      .join('\n');
  final eventsBlock = weekFutureEvents
      .map(
        (event) =>
            '- ${event.title} (${_formatEventRange(event.start, event.end)})',
      )
      .join('\n');
  final domainEligibility =
      buildAnalysisChecklistDomainEligibilityBlock(selection);
  final domainSections = buildAnalysisChecklistDomainSectionsBlock(selection);

  return '''
Repair one weekly checklist segment from a monthly insights report.

Checklist month: ${period.checklistMonthLabel}
Week: $weekHeader
$domainEligibility

The following Future Events MUST appear by exact event title in #### **Calendar & Schedule**:
$missingTitles

Source Future Events scheduled for this week:
$eventsBlock

Current incomplete week section:
$currentWeekMarkdown

Output ONLY the replacement week block:
- Start with ##### **Week ${week.weekNumber} · ${week.isoRangeLabel} · [Theme: Recovery | Stabilization | Improvement | Maintenance | Review]**
- Include every required #### subsection below in priority order — do not skip domains:
$domainSections
- In #### **Calendar & Schedule**, name every Future Event listed above by exact title and tie directives to those events.

Do not output any other weeks or sections. Do not wrap in code fences.''';
}

String _formatEventRange(DateTime start, DateTime end) {
  final day = DateFormat('d MMM yyyy');
  final startLabel = day.format(start);
  final endLabel = day.format(end);
  if (startLabel == endLabel) return startLabel;
  return '$startLabel – $endLabel';
}
