import 'package:intl/intl.dart';

import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_prompt_builder.dart';
import 'package:personal/features/location/timeline_activity.dart';

const _calendarImpactWindowDays = 3;

class MajorCalendarEvent {
  const MajorCalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    required this.isHoliday,
    this.dayCount,
    this.overnightTravel = false,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final bool isHoliday;
  final int? dayCount;
  final bool overnightTravel;

  String get impactLabel => shortImpactLabel(title, isHoliday: isHoliday);
}

class CalendarPromptEvent {
  const CalendarPromptEvent({
    required this.title,
    required this.start,
    required this.end,
    required this.isHoliday,
    this.dayCount,
    this.overnightStay = false,
    this.timeOfDay,
    this.eventStart,
    this.eventEnd,
    this.allDay = true,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final bool isHoliday;
  final int? dayCount;
  final bool overnightStay;
  final String? timeOfDay;
  final DateTime? eventStart;
  final DateTime? eventEnd;
  final bool allDay;

  bool get isMultiDay => _dateOnly(end).isAfter(_dateOnly(start));

  bool get isTripLike =>
      overnightStay || title.toLowerCase().contains('trip');

  bool get disruptsEveningSleep =>
      timeOfDay == 'Evening' || timeOfDay == 'Night';
}

String buildCalendarPromptText(
  CalendarSummary summary, {
  CalendarSummary? upcomingSource,
  DateTime? upcomingAfter,
  LocationSummary? location,
  ExpensesSummary? expenses,
}) {
  final hasPeriodEvents = summary.events.isNotEmpty;
  final hasUpcomingSource =
      upcomingSource != null && upcomingSource.events.isNotEmpty;

  if (!hasPeriodEvents && !hasUpcomingSource) {
    return 'No Google Calendar events synced.';
  }

  final periodEvents = hasPeriodEvents
      ? listCalendarPromptEvents(summary)
      : const <CalendarPromptEvent>[];
  final upcomingEvents = hasUpcomingSource
      ? listUpcomingCalendarPromptEvents(
          upcomingSource,
          after: upcomingAfter ??
              summary.rangeEnd ??
              (summary.events.isNotEmpty
                  ? summary.events.last.start
                  : DateTime.now()),
        )
      : const <CalendarPromptEvent>[];

  if (periodEvents.isEmpty && upcomingEvents.isEmpty) {
    return 'No calendar events in this period.';
  }

  final buffer = StringBuffer();

  if (periodEvents.isNotEmpty) {
    buffer.write('Calendar Events');
    _writeCalendarEvents(
      buffer,
      periodEvents,
      location: location,
      expenses: expenses,
    );
  }

  if (upcomingEvents.isNotEmpty) {
    if (buffer.isNotEmpty) buffer.writeln();
    buffer.write('Upcoming Events');
    _writeCalendarEvents(
      buffer,
      upcomingEvents,
      location: location,
      expenses: expenses,
    );
  }

  return buffer.toString().trimRight();
}

String buildCalendarImpactDerivedText(
  CalendarSummary summary, {
  MonthlyHealthSummary? health,
  ExpensesSummary? expenses,
}) {
  if (summary.events.isEmpty || health == null || health.sleepNightsTracked == 0) {
    return '';
  }

  final events = listCalendarPromptEvents(summary);
  if (events.isEmpty) return '';

  final sections = <String>[];
  for (final event in events) {
    final lines = _impactLinesForEvent(
      event,
      dailySleep: health.dailySleep,
      expenses: expenses,
    );
    sections.add(
      '${shortImpactLabel(event.title, isHoliday: event.isHoliday)}:\n'
      '${lines.map((line) => '- $line').join('\n')}',
    );
  }

  return sections.join('\n\n');
}

void _writeCalendarEvents(
  StringBuffer buffer,
  List<CalendarPromptEvent> events, {
  LocationSummary? location,
  ExpensesSummary? expenses,
}) {
  for (final event in events) {
    buffer
      ..writeln()
      ..writeln()
      ..writeln(_formatEventDateHeader(event.start, event.end))
      ..writeln('- ${event.title}');

    if (event.isHoliday) {
      buffer.writeln('- Duration: ${event.dayCount ?? 1} days');
    } else if (event.timeOfDay != null) {
      buffer.writeln('- ${event.timeOfDay} event');
    } else {
      buffer.writeln(
        '- Overnight stay: ${event.overnightStay ? 'Yes' : 'No'}',
      );
    }

    final period = _eventPeriod(event);
    final motorcycleTrips = _motorcycleTripsDuring(
      location,
      period.start,
      period.end,
    );
    if (motorcycleTrips.isNotEmpty) {
      final distanceMeters = motorcycleTrips.fold(
        0.0,
        (sum, trip) => sum + trip.distanceMeters,
      );
      final travelTime = motorcycleTrips.fold(
        Duration.zero,
        (sum, trip) => sum + trip.duration,
      );
      buffer.writeln(
        '- Motorcycle movement: '
        '${(distanceMeters / 1000).toStringAsFixed(2)} km · '
        '${formatTravelDuration(travelTime)}',
      );
    }

    final purchases = _purchasesDuring(
      expenses,
      period.start,
      period.end,
    );
    for (final purchase in purchases) {
      final currency = expenses?.currency ?? purchase.currency;
      buffer.writeln(
        '- Purchase: ${ExpensesSummary.purchasePromptLabel(purchase)} · '
        '${formatExpenseMoney(purchase.amount.abs())} $currency',
      );
    }
  }
}

List<String> _impactLinesForEvent(
  CalendarPromptEvent event, {
  required List<DailySleepEntry> dailySleep,
  ExpensesSummary? expenses,
}) {
  final eventStart = _dateOnly(event.start);
  final eventEnd = _dateOnly(event.end);
  final beforeStart = eventStart.subtract(
    const Duration(days: _calendarImpactWindowDays),
  );
  final beforeEnd = eventStart.subtract(const Duration(days: 1));
  final afterStart = eventEnd.add(const Duration(days: 1));
  final afterEnd = eventEnd.add(
    const Duration(days: _calendarImpactWindowDays),
  );

  final sleepBefore = _averageSleepInWakeRange(dailySleep, beforeStart, beforeEnd);
  final sleepDuring = _averageSleepInWakeRange(dailySleep, eventStart, eventEnd);
  final sleepAfter = _averageSleepInWakeRange(dailySleep, afterStart, afterEnd);

  final spendBefore = _spendingInRange(expenses, beforeStart, beforeEnd);
  final spendDuring = _spendingInRange(expenses, eventStart, eventEnd);
  final spendAfter = _spendingInRange(expenses, afterStart, afterEnd);

  final lines = <String>[
    'Before Window: $_calendarImpactWindowDays days before',
    'During Window: event duration',
    'After Window: $_calendarImpactWindowDays days after',
    'Average sleep before: ${_formatSleepAverage(sleepBefore)}',
    'Average sleep during: ${_formatSleepAverage(sleepDuring)}',
    'Average sleep after: ${_formatSleepAverage(sleepAfter)}',
    'Spending before: ${_formatSpending(spendBefore, expenses?.currency)}',
    'Spending during: ${_formatSpending(spendDuring, expenses?.currency)}',
    'Spending after: ${_formatSpending(spendAfter, expenses?.currency)}',
  ];

  final disruption = sleepDuring != null &&
      sleepBefore != null &&
      sleepDuring.inMinutes < sleepBefore.inMinutes - 15;
  lines.add('Sleep disruption: ${disruption ? 'Yes' : 'No'}');

  final recovered = sleepAfter != null &&
      sleepBefore != null &&
      sleepAfter.inMinutes >= sleepBefore.inMinutes - 15;
  lines.add('Recovery: ${recovered ? 'Recovered' : 'Not recovered'}');

  return lines;
}

Duration? _averageSleepInWakeRange(
  List<DailySleepEntry> dailySleep,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final start = _dateOnly(rangeStart);
  final end = _dateOnly(rangeEnd);
  final nights = dailySleep
      .where(
        (night) =>
            night.hasData &&
            !_dateOnly(night.wakeDate).isBefore(start) &&
            !_dateOnly(night.wakeDate).isAfter(end),
      )
      .toList();
  if (nights.isEmpty) return null;

  final totalMinutes = nights
      .map((night) => night.session!.duration.inMinutes)
      .reduce((a, b) => a + b);
  return Duration(minutes: (totalMinutes / nights.length).round());
}

double? _spendingInRange(
  ExpensesSummary? expenses,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  if (expenses == null) return null;
  final start = _dateOnly(rangeStart);
  final end = _dateOnly(rangeEnd);
  final total = expenses.transactions
      .where(
        (tx) =>
            tx.isRealExpense &&
            !_dateOnly(tx.date).isBefore(start) &&
            !_dateOnly(tx.date).isAfter(end),
      )
      .fold(0.0, (sum, tx) => sum + tx.amount.abs());
  return total;
}

String _formatSleepAverage(Duration? duration) {
  if (duration == null) return 'n/a';
  return formatDurationPadded(duration);
}

String _formatSpending(double? amount, String? currency) {
  if (amount == null) return 'n/a';
  final label = formatExpenseMoney(amount, alwaysTwoDecimals: true);
  if (currency == null || currency.isEmpty) return label;
  return '$label $currency';
}

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
  return listUpcomingCalendarPromptEvents(source, after: after)
      .map(_majorEventFromPromptEvent)
      .toList();
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

List<MajorCalendarEvent> _majorPersonalEvents(
  Iterable<CalendarEvent> events,
) {
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
    if (lower.contains('eid')) return 'Eid';
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

DateTime _dateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

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

  return _EventPeriod(
    start: event.eventStart!,
    end: event.eventEnd!,
  );
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
