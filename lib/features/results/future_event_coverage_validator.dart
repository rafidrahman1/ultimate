import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/results/checklist_week_markdown.dart';

class FutureEventWeekAssignment {
  const FutureEventWeekAssignment({
    required this.event,
    required this.weekNumber,
  });

  final CalendarPromptEvent event;
  final int weekNumber;

  String get eventTitle => event.title;
}

class FutureEventCoverageMiss {
  const FutureEventCoverageMiss({
    required this.eventTitle,
    required this.weekNumber,
    required this.reason,
  });

  final String eventTitle;
  final int weekNumber;
  final String reason;
}

List<CalendarPromptEvent> parseFutureEventsFromSource({
  required CalendarSummary upcomingSource,
  required DateTime after,
}) {
  return listUpcomingCalendarPromptEvents(upcomingSource, after: after);
}

List<FutureEventWeekAssignment> assignFutureEventsToChecklistWeeks({
  required List<CalendarPromptEvent> futureEvents,
  required AnalysisPeriod period,
}) {
  final assignments = <FutureEventWeekAssignment>[];
  for (final event in futureEvents) {
    final weekNumber = weekNumberForChecklistDate(event.start, period);
    if (weekNumber == null) continue;
    assignments.add(
      FutureEventWeekAssignment(event: event, weekNumber: weekNumber),
    );
  }
  return assignments;
}

int? weekNumberForChecklistDate(DateTime date, AnalysisPeriod period) {
  final local = DateTime(date.year, date.month, date.day);
  for (final week in period.checklistWeeks) {
    if (isDateInRange(local, week.start, week.end)) {
      return week.weekNumber;
    }
  }
  return null;
}

List<FutureEventCoverageMiss> findMissingFutureEventCoverage({
  required String markdown,
  required List<FutureEventWeekAssignment> assignments,
}) {
  if (assignments.isEmpty) return const [];

  final sectionsByWeek = {
    for (final section in parseChecklistWeekSections(markdown))
      section.weekNumber: section,
  };

  final missing = <FutureEventCoverageMiss>[];
  for (final assignment in assignments) {
    final section = sectionsByWeek[assignment.weekNumber];
    if (section == null) {
      missing.add(
        FutureEventCoverageMiss(
          eventTitle: assignment.eventTitle,
          weekNumber: assignment.weekNumber,
          reason: 'week section not found',
        ),
      );
      continue;
    }

    final calendarBlock = extractCalendarScheduleBlock(section.markdown);
    if (calendarBlock == null || calendarBlock.isEmpty) {
      missing.add(
        FutureEventCoverageMiss(
          eventTitle: assignment.eventTitle,
          weekNumber: assignment.weekNumber,
          reason: 'calendar subsection missing',
        ),
      );
      continue;
    }

    if (!calendarSectionMentionsEvent(calendarBlock, assignment.eventTitle)) {
      missing.add(
        FutureEventCoverageMiss(
          eventTitle: assignment.eventTitle,
          weekNumber: assignment.weekNumber,
          reason: 'event title not mentioned',
        ),
      );
    }
  }
  return missing;
}

bool isFutureEventCoverageComplete({
  required String markdown,
  required List<FutureEventWeekAssignment> assignments,
}) {
  return findMissingFutureEventCoverage(
    markdown: markdown,
    assignments: assignments,
  ).isEmpty;
}
