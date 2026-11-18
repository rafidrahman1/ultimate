import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/calendar/data/calendar_event.dart';
import 'package:personal/features/calendar/data/leave_days.dart';

CalendarEvent _allDay(String title, DateTime first, int days) => CalendarEvent(
  title: title,
  start: first,
  end: DateTime(first.year, first.month, first.day + days),
  allDay: true,
);

void main() {
  test('titles map to sick or casual leave', () {
    expect(leaveTypeOfTitle('Sick leave'), LeaveType.sick);
    expect(leaveTypeOfTitle('SL - fever'), LeaveType.sick);
    expect(leaveTypeOfTitle('Casual Leave'), LeaveType.casual);
    expect(leaveTypeOfTitle('CL'), LeaveType.casual);
    expect(leaveTypeOfTitle('Leave for airport'), isNull);
    expect(leaveTypeOfTitle('Clinic visit'), isNull);
    expect(leaveTypeOfTitle('Slack sync'), isNull);
  });

  test('multi-day all-day leave marks each day, not the day after', () {
    final days = leaveDaysOf([
      _allDay('Sick leave', DateTime(2026, 11, 3), 2),
      _allDay('CL', DateTime(2026, 11, 10), 1),
    ]);
    expect(days, {
      DateTime(2026, 11, 3): LeaveType.sick,
      DateTime(2026, 11, 4): LeaveType.sick,
      DateTime(2026, 11, 10): LeaveType.casual,
    });
  });

  test('sick wins when leave kinds overlap; holidays are ignored', () {
    final days = leaveDaysOf([
      _allDay('Casual leave', DateTime(2026, 11, 5), 1),
      _allDay('Sick', DateTime(2026, 11, 5), 1),
      CalendarEvent(
        title: 'Sick leave',
        start: DateTime(2026, 11, 6),
        end: DateTime(2026, 11, 7),
        allDay: true,
        isHoliday: true,
      ),
    ]);
    expect(days, {DateTime(2026, 11, 5): LeaveType.sick});
  });
}
