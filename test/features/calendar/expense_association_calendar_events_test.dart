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
          ),
        ],
      ),
    );

    expect(events, hasLength(1));
    expect(events.single.title, 'Dinner with friends');
  });

  test('listMajorCalendarEvents still omits single-day personal events', () {
    final events = listMajorCalendarEvents(
      CalendarSummary(
        events: [
          CalendarEvent(
            title: 'Dinner with friends',
            start: DateTime(2026, 6, 13, 19),
            end: DateTime(2026, 6, 13, 21),
          ),
        ],
      ),
    );

    expect(events, isEmpty);
  });
}
