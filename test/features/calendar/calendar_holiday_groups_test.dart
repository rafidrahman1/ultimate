import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_holiday_groups.dart';

void main() {
  test('groupConsecutiveHolidays merges multi-day Eid stretch', () {
    final events = <CalendarEvent>[
      for (final day in [25, 26, 27, 28, 29, 30, 31])
        CalendarEvent(
          title: day == 28 ? 'Eid al-Adha' : 'Eid al-Adha Holiday',
          start: DateTime(2026, 5, day),
          end: DateTime(2026, 5, day + 1),
          allDay: true,
          isHoliday: true,
        ),
    ];

    final groups = groupConsecutiveHolidays(events);

    expect(groups, hasLength(1));
    expect(groups.first.dayCount, 7);
    expect(groups.first.title, 'Eid al-Adha');
    expect(groups.first.start, DateTime(2026, 5, 25));
    expect(groups.first.end, DateTime(2026, 5, 31));
  });

  test('groupConsecutiveHolidays keeps separate holidays on same day apart', () {
    final events = [
      CalendarEvent(
        title: 'Buddha Purnima/Vesak',
        start: DateTime(2026, 5, 1),
        end: DateTime(2026, 5, 2),
        allDay: true,
        isHoliday: true,
      ),
      CalendarEvent(
        title: 'May Day',
        start: DateTime(2026, 5, 1),
        end: DateTime(2026, 5, 2),
        allDay: true,
        isHoliday: true,
      ),
    ];

    final groups = groupConsecutiveHolidays(events);

    expect(groups, hasLength(2));
  });

  test('toAnalysisPromptText groups multi-day holidays into one major event', () {
    final summary = CalendarSummary(
      events: [
        CalendarEvent(
          title: 'Eid al-Adha Holiday',
          start: DateTime(2026, 5, 25),
          end: DateTime(2026, 5, 26),
          allDay: true,
          isHoliday: true,
        ),
        CalendarEvent(
          title: 'Eid al-Adha Holiday',
          start: DateTime(2026, 5, 26),
          end: DateTime(2026, 5, 27),
          allDay: true,
          isHoliday: true,
        ),
        CalendarEvent(
          title: 'Eid al-Adha',
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
          allDay: true,
          isHoliday: true,
        ),
      ],
      rangeStart: DateTime(2026, 5, 1),
      rangeEnd: DateTime(2026, 6, 30),
    );

    final text = summary.toAnalysisPromptText();

    expect(text, contains('Major Events'));
    expect(text, contains('25–27 May'));
    expect(text, contains('- Eid al-Adha'));
    expect(text, contains('- Duration: 3 days'));
  });
}
