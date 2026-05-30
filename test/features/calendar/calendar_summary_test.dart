import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/calendar/calendar_event.dart';

void main() {
  test('toAnalysisPromptText lists synced events', () {
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
        ),
      ],
      accountEmail: 'user@example.com',
      rangeStart: DateTime(2026, 5, 23),
      rangeEnd: DateTime(2026, 6, 13),
    );

    final text = summary.toAnalysisPromptText();

    expect(text, contains('Account: user@example.com'));
    expect(text, contains('Team standup'));
    expect(text, contains('Holiday'));
  });
}
