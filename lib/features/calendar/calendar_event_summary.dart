import 'package:personal/features/calendar/calendar_event.dart';

class MajorCalendarEvent {
  const MajorCalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    required this.isHoliday,
    this.dayCount,
    this.overnightTravel = false,
    this.allDay = false,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final bool isHoliday;
  final int? dayCount;
  final bool overnightTravel;
  final bool allDay;

  String get impactLabel => shortImpactLabel(title, isHoliday: isHoliday);
}

/// Multi-day/major personal events plus holiday groups, merged and sorted.
List<MajorCalendarEvent> listMajorCalendarEvents(CalendarSummary summary) {
  final events = <MajorCalendarEvent>[
    for (final group in summary.holidayGroups)
      MajorCalendarEvent(
        title: group.title,
        start: _dateOnly(group.start),
        end: _dateOnly(group.end),
        isHoliday: true,
        dayCount: group.dayCount,
      ),
    ..._majorPersonalEvents(summary.events.where((event) => !event.isHoliday)),
  ]..sort((a, b) => a.start.compareTo(b.start));

  return events;
}

/// Calendar events for expense-to-schedule association tags.
///
/// Unlike [listMajorCalendarEvents], this includes single-day personal events
/// so restaurant and outing purchases can link to same-day calendar entries.
List<MajorCalendarEvent> listExpenseAssociationCalendarEvents(
  CalendarSummary summary,
) {
  final events = <MajorCalendarEvent>[
    for (final group in summary.holidayGroups)
      MajorCalendarEvent(
        title: group.title,
        start: _dateOnly(group.start),
        end: _endOfDay(_dateOnly(group.end)),
        isHoliday: true,
        dayCount: group.dayCount,
        allDay: true,
      ),
    for (final event in summary.events.where((event) => !event.isHoliday))
      if (event.allDay)
        MajorCalendarEvent(
          title: event.title,
          start: _dateOnly(event.start),
          end: _endOfDay(_eventLastInclusiveDay(event)),
          isHoliday: false,
          overnightTravel: _hasOvernightStay(event),
          allDay: true,
        )
      else
        MajorCalendarEvent(
          title: event.title,
          start: event.start.toLocal(),
          end: event.end.toLocal(),
          isHoliday: false,
          overnightTravel: _hasOvernightStay(event),
          allDay: false,
        ),
  ]..sort((a, b) => a.start.compareTo(b.start));

  return events;
}

List<MajorCalendarEvent> _majorPersonalEvents(Iterable<CalendarEvent> events) {
  final qualifying = events.where(_isMajorPersonalEvent).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  if (qualifying.isEmpty) return const [];

  final merged = <MajorCalendarEvent>[];
  var blockTitle = qualifying.first.title;
  var blockStart = _eventFirstDay(qualifying.first);
  var blockEnd = _eventLastInclusiveDay(qualifying.first);
  var blockOvernight = _hasOvernightStay(qualifying.first);

  for (final event in qualifying.skip(1)) {
    final titleKey = _personalEventKey(event.title);
    final firstDay = _eventFirstDay(event);
    final lastDay = _eventLastInclusiveDay(event);

    if (titleKey == _personalEventKey(blockTitle) &&
        firstDay.difference(blockEnd).inDays == 1) {
      blockEnd = lastDay;
      blockOvernight = blockOvernight || _hasOvernightStay(event);
      continue;
    }

    merged.add(
      MajorCalendarEvent(
        title: blockTitle,
        start: blockStart,
        end: blockEnd,
        isHoliday: false,
        overnightTravel: blockOvernight,
      ),
    );
    blockTitle = event.title;
    blockStart = firstDay;
    blockEnd = lastDay;
    blockOvernight = _hasOvernightStay(event);
  }

  merged.add(
    MajorCalendarEvent(
      title: blockTitle,
      start: blockStart,
      end: blockEnd,
      isHoliday: false,
      overnightTravel: blockOvernight,
    ),
  );

  return merged;
}

String shortImpactLabel(String title, {bool isHoliday = false}) {
  if (isHoliday) {
    final lower = title.toLowerCase();
    if (lower.contains('eid')) return 'Eid al-Adha';
    return title;
  }

  final lower = title.toLowerCase();
  for (final keyword in [
    'wedding',
    'trip',
    'interview',
    'training',
    'visit',
    'conference',
  ]) {
    if (lower.contains(keyword)) {
      return keyword[0].toUpperCase() + keyword.substring(1);
    }
  }

  final first = title.trim().split(RegExp(r'\s+')).first;
  if (first.isEmpty) return title;
  return first[0].toUpperCase() + first.substring(1).toLowerCase();
}

bool _isMajorPersonalEvent(CalendarEvent event) {
  final first = _eventFirstDay(event);
  final last = _eventLastInclusiveDay(event);
  return last.difference(first).inDays >= 1;
}

bool _hasOvernightStay(CalendarEvent event) {
  final first = _eventFirstDay(event);
  final last = _eventLastInclusiveDay(event);
  if (last.isAfter(first)) return true;
  if (event.allDay) return false;
  return _dateOnly(event.start) != _dateOnly(event.end);
}

String _personalEventKey(String title) => title.trim().toLowerCase();

DateTime _eventFirstDay(CalendarEvent event) => _dateOnly(event.start);

DateTime _eventLastInclusiveDay(CalendarEvent event) {
  if (event.allDay) {
    final endDay = _dateOnly(event.end);
    return endDay.subtract(const Duration(days: 1));
  }
  return _dateOnly(event.end);
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _endOfDay(DateTime date) =>
    date.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
