import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/google_calendar_client.dart';

void main() {
  test('mergeCalendarEvents dedupes same title on same day', () {
    final personal = [
      CalendarEvent(
        title: 'Independence Day',
        start: DateTime(2026, 3, 26),
        end: DateTime(2026, 3, 27),
        allDay: true,
      ),
    ];
    final holidays = [
      CalendarEvent(
        title: 'Independence Day',
        start: DateTime(2026, 3, 26),
        end: DateTime(2026, 3, 27),
        allDay: true,
        isHoliday: true,
      ),
      CalendarEvent(
        title: 'Eid ul-Fitr',
        start: DateTime(2026, 3, 30),
        end: DateTime(2026, 3, 31),
        allDay: true,
        isHoliday: true,
      ),
    ];

    final merged = mergeCalendarEvents(personal, holidays);

    expect(merged, hasLength(2));
    expect(merged.where((e) => e.isHoliday), hasLength(1));
    expect(merged.singleWhere((e) => e.title == 'Independence Day').isHoliday, isFalse);
    expect(merged.any((e) => e.title == 'Eid ul-Fitr'), isTrue);
  });
}
