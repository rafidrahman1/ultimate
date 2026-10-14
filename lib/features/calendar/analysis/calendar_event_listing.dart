part of 'calendar_prompt_builder.dart';

// Selecting and classifying calendar events (major, upcoming, expense-linked) plus date helpers.

List<CalendarPromptEvent> listCalendarPromptEvents(CalendarSummary summary) {
  final events = <CalendarPromptEvent>[
    for (final group in summary.holidayGroups)
      CalendarPromptEvent(
        title: group.title,
        start: _dateOnly(group.start),
        end: _dateOnly(group.end),
        isHoliday: true,
        dayCount: group.dayCount,
        eventStart: _dateOnly(group.start),
        eventEnd: _endOfDay(_dateOnly(group.end)),
        allDay: true,
      ),
    for (final event in summary.events.where((entry) => !entry.isHoliday))
      _calendarPromptEventFrom(event),
  ]..sort((a, b) => a.start.compareTo(b.start));

  return events;
}

List<CalendarPromptEvent> listUpcomingCalendarPromptEvents(
  CalendarSummary source, {
  required DateTime after,
}) {
  final cutoff = _dateOnly(after);
  final upcoming = source.events
      .where((event) => _eventFirstDay(event).isAfter(cutoff))
      .toList();
  if (upcoming.isEmpty) return const [];

  return listCalendarPromptEvents(CalendarSummary(events: upcoming));
}

CalendarPromptEvent _calendarPromptEventFrom(CalendarEvent event) {
  final start = _eventFirstDay(event);
  final end = _eventLastInclusiveDay(event);
  return CalendarPromptEvent(
    title: event.title,
    start: start,
    end: end,
    isHoliday: false,
    overnightStay: _hasOvernightStay(event),
    timeOfDay: event.allDay ? null : _timeOfDayLabel(event.start),
    eventStart: event.start,
    eventEnd: event.end,
    allDay: event.allDay,
  );
}

List<MajorCalendarEvent> listUpcomingCalendarEvents(
  CalendarSummary source, {
  required DateTime after,
}) {
  return listUpcomingCalendarPromptEvents(
    source,
    after: after,
  ).map(_majorEventFromPromptEvent).toList();
}

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

MajorCalendarEvent _majorEventFromPromptEvent(CalendarPromptEvent event) {
  return MajorCalendarEvent(
    title: event.title,
    start: event.start,
    end: event.end,
    isHoliday: event.isHoliday,
    dayCount: event.dayCount,
    overnightTravel: event.overnightStay,
  );
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

String _timeOfDayLabel(DateTime dateTime) {
  final hour = dateTime.toLocal().hour;
  if (hour >= 5 && hour < 12) return 'Morning';
  if (hour >= 12 && hour < 17) return 'Afternoon';
  if (hour >= 17 && hour < 22) return 'Evening';
  return 'Night';
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

String _formatEventDateHeader(DateTime start, DateTime end) {
  if (_dateOnly(start) == _dateOnly(end)) {
    return _formatShortDate(start);
  }
  if (start.month == end.month && start.year == end.year) {
    return '${start.day}–${end.day} ${DateFormat('MMM').format(start)}';
  }
  return '${_formatShortDate(start)} – ${_formatShortDate(end)}';
}

String _formatShortDate(DateTime date) =>
    DateFormat('d MMM').format(date.toLocal());

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _endOfDay(DateTime date) =>
    date.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

class _EventPeriod {
  const _EventPeriod({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

_EventPeriod _eventPeriod(CalendarPromptEvent event) {
  if (event.allDay) {
    return _EventPeriod(
      start: _dateOnly(event.start),
      end: _endOfDay(_dateOnly(event.end)),
    );
  }

  return _EventPeriod(start: event.eventStart!, end: event.eventEnd!);
}

List<TimelineActivity> _motorcycleTripsDuring(
  LocationSummary? location,
  DateTime periodStart,
  DateTime periodEnd,
) {
  if (location == null || !location.hasAnyData) return const [];

  return location.periodMotorcyclingActivities
      .where(
        (trip) =>
            trip.distanceMeters > 0 &&
            trip.startTime.isBefore(periodEnd) &&
            trip.endTime.isAfter(periodStart),
      )
      .toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
}

List<CashewTransaction> _purchasesDuring(
  ExpensesSummary? expenses,
  DateTime purchaseStart,
  DateTime purchaseEnd,
) {
  if (expenses == null) return const [];

  return expenses.transactions
      .where(
        (tx) =>
            tx.isRealExpense &&
            !tx.date.isBefore(purchaseStart) &&
            !tx.date.isAfter(purchaseEnd),
      )
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}
