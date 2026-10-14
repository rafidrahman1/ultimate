import 'package:personal/features/calendar/calendar_event.dart';

/// Friday and Saturday, the Bangladesh weekend, used until weekend days are
/// set in the personal profile.
const defaultWeekendDays = [DateTime.friday, DateTime.saturday];

/// Days covered by public holidays among [events].
Set<DateTime> holidayDaysOf(Iterable<CalendarEvent> events) {
  final out = <DateTime>{};
  for (final e in events) {
    if (!e.isHoliday) continue;
    final first = DateTime(e.start.year, e.start.month, e.start.day);
    var last = DateTime(e.end.year, e.end.month, e.end.day);
    // An all-day event ends at midnight after its last day.
    if (e.allDay && last.isAfter(first)) {
      last = last.subtract(const Duration(days: 1));
    }
    for (
      var d = first;
      !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      out.add(d);
    }
  }
  return out;
}

/// True when [day] is a weekend day or a public holiday. An empty
/// [weekendDays] means [defaultWeekendDays].
bool isDayOffOn(
  DateTime day, {
  List<int> weekendDays = const [],
  Set<DateTime> holidays = const {},
}) =>
    (weekendDays.isEmpty ? defaultWeekendDays : weekendDays).contains(
      day.weekday,
    ) ||
    holidays.contains(DateTime(day.year, day.month, day.day));
