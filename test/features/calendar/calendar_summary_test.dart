import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/calendar/calendar_event.dart';

void main() {
  test('forSyncedDisplayRange includes upcoming events after analysis month end', () {
    final summary = CalendarSummary(
      events: [
        CalendarEvent(
          title: 'Past meeting',
          start: DateTime(2026, 6, 5, 10),
          end: DateTime(2026, 6, 5, 11),
          allDay: false,
        ),
        CalendarEvent(
          title: 'Upcoming meeting',
          start: DateTime(2026, 6, 20, 10),
          end: DateTime(2026, 6, 20, 11),
          allDay: false,
        ),
        CalendarEvent(
          title: 'Next month event',
          start: DateTime(2026, 7, 4, 10),
          end: DateTime(2026, 7, 4, 11),
          allDay: false,
        ),
      ],
    );

    final analysisPeriod = AnalysisPeriod.forDataMonth(
      DateTime(2026, 6, 1),
      DateTime(2026, 6, 11),
    );
    final analysisView = summary.forAnalysisPeriod(analysisPeriod);
    final displayView = summary.forSyncedDisplayRange(DateTime(2026, 6, 1));

    expect(analysisView.events.map((e) => e.title), ['Past meeting']);
    expect(
      displayView.events.map((e) => e.title),
      ['Past meeting', 'Upcoming meeting', 'Next month event'],
    );
    expect(displayView.upcomingEvents.length, 2);
  });

  test('toAnalysisPromptText reports no major events for routine calendar items', () {
    final summary = CalendarSummary(
      events: [
        CalendarEvent(
          title: 'Team standup',
          start: DateTime(2026, 5, 30, 10, 0),
          end: DateTime(2026, 5, 30, 10, 30),
          allDay: false,
        ),
        CalendarEvent(
          title: 'Holiday',
          start: DateTime(2026, 5, 31),
          end: DateTime(2026, 6, 1),
          allDay: true,
          isHoliday: true,
        ),
      ],
      accountEmail: 'user@example.com',
      rangeStart: DateTime(2026, 5, 23),
      rangeEnd: DateTime(2026, 6, 13),
    );

    final text = summary.toAnalysisPromptText();

    expect(text, contains('Major Events'));
    expect(text, contains('31 May'));
    expect(text, contains('Holiday'));
    expect(text, isNot(contains('Team standup')));
  });
}
