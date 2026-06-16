import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/results/future_event_coverage_validator.dart';

const _outputMissingEvent = '''
### **Clear Next Actions (June 2026)**

##### **Week 1 · 2026-06-01 to 2026-06-07 · Theme: Recovery**

#### **Calendar & Schedule**
* **Prep:** Keep evenings free.

##### **Week 2 · 2026-06-08 to 2026-06-14 · Theme: Stabilization**

#### **Calendar & Schedule**
* **Routine:** Maintain work blocks.
''';

const _outputComplete = '''
### **Clear Next Actions (June 2026)**

##### **Week 2 · 2026-06-08 to 2026-06-14 · Theme: Stabilization**

#### **Calendar & Schedule**
* **Family Visit:** Lower targets during the 8–10 Jun visit.
''';

void main() {
  late AnalysisPeriod period;
  late List<FutureEventWeekAssignment> assignments;

  setUp(() {
    period = AnalysisPeriod.forDataMonth(DateTime(2026, 5, 1));
    assignments = assignFutureEventsToChecklistWeeks(
      futureEvents: [
        CalendarPromptEvent(
          title: 'Family Visit',
          start: DateTime(2026, 6, 8),
          end: DateTime(2026, 6, 10),
          isHoliday: false,
          eventStart: DateTime(2026, 6, 8),
          eventEnd: DateTime(2026, 6, 10),
          allDay: true,
        ),
      ],
      period: period,
    );
  });

  test('assignFutureEventsToChecklistWeeks maps by event start date', () {
    expect(assignments, hasLength(1));
    expect(assignments.single.weekNumber, 2);
  });

  test('findMissingFutureEventCoverage flags absent titles', () {
    final missing = findMissingFutureEventCoverage(
      markdown: _outputMissingEvent,
      assignments: assignments,
    );

    expect(missing, hasLength(1));
    expect(missing.single.eventTitle, 'Family Visit');
    expect(missing.single.weekNumber, 2);
  });

  test('isFutureEventCoverageComplete passes when titles are present', () {
    expect(
      isFutureEventCoverageComplete(
        markdown: _outputComplete,
        assignments: assignments,
      ),
      isTrue,
    );
  });

  test('parseFutureEventsFromSource reads upcoming events after analysis end', () {
    final upcoming = CalendarSummary(
      events: [
        CalendarEvent(
          title: 'Dentist',
          start: DateTime(2026, 6, 12, 10),
          end: DateTime(2026, 6, 12, 11),
          allDay: false,
        ),
      ],
    );

    final events = parseFutureEventsFromSource(
      upcomingSource: upcoming,
      after: period.dataMonthEnd,
    );

    expect(events, hasLength(1));
    expect(events.single.title, 'Dentist');
  });
}
