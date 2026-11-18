import 'package:personal/features/calendar/data/calendar_event.dart';

/// Kind of leave a calendar event records.
enum LeaveType {
  sick('Sick leave', 'Sick'),
  casual('Casual leave', 'Casual');

  const LeaveType(this.label, this.shortLabel);

  final String label;
  final String shortLabel;
}

final _sick = RegExp(r'\bsick\b|\bsl\b', caseSensitive: false);
final _casual = RegExp(r'\bcasual\b|\bcl\b', caseSensitive: false);

/// The leave an event title records, e.g. "Sick leave", "SL", "Casual leave"
/// or "CL"; null for anything else.
LeaveType? leaveTypeOfTitle(String title) {
  if (_sick.hasMatch(title)) return LeaveType.sick;
  if (_casual.hasMatch(title)) return LeaveType.casual;
  return null;
}

/// Local days covered by sick or casual leave among [events]. A multi-day
/// event marks every day it spans; when two kinds overlap, sick wins.
Map<DateTime, LeaveType> leaveDaysOf(Iterable<CalendarEvent> events) {
  final out = <DateTime, LeaveType>{};
  for (final e in events) {
    if (e.isHoliday) continue;
    final type = leaveTypeOfTitle(e.title);
    if (type == null) continue;
    final start = e.start.toLocal();
    final end = e.end.toLocal();
    final first = DateTime(start.year, start.month, start.day);
    var last = DateTime(end.year, end.month, end.day);
    // An all-day event ends at midnight after its last day.
    if (e.allDay && last.isAfter(first)) {
      last = DateTime(last.year, last.month, last.day - 1);
    }
    for (
      var d = first;
      !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (out[d] != LeaveType.sick) out[d] = type;
    }
  }
  return out;
}
