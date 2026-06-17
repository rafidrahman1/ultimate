import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';

void main() {
  test('listExpenseAssociationCalendarEvents includes single-day personal events', () {
    final events = listExpenseAssociationCalendarEvents(
      CalendarSummary(
        events: [
          CalendarEvent(
            title: 'Dinner with friends',
            start: DateTime(2026, 6, 13, 19),
            end: DateTime(2026, 6, 13, 21),
            allDay: false,
          ),
        ],
      ),
    );

    expect(events, hasLength(1));
    expect(events.single.allDay, isFalse);
    expect(events.single.start, DateTime(2026, 6, 13, 19));
    expect(events.single.end, DateTime(2026, 6, 13, 21));
  });

  test('listMajorCalendarEvents still omits single-day personal events', () {
    final events = listMajorCalendarEvents(
      CalendarSummary(
        events: [
          CalendarEvent(
            title: 'Dinner with friends',
            start: DateTime(2026, 6, 13, 19),
            end: DateTime(2026, 6, 13, 21),
            allDay: false,
          ),
        ],
      ),
    );

    expect(events, isEmpty);
  });
}
