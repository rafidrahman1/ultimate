import 'package:intl/intl.dart';

import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_holiday_groups.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_anomaly.dart';

const _postEventImpactDays = 3;

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

  String get impactLabel => _impactLabel(title, isHoliday: isHoliday);
}

String buildCalendarPromptText(
  CalendarSummary summary, {
  MonthlyHealthSummary? health,
}) {
  if (summary.events.isEmpty) {
    return 'No Google Calendar events synced.';
  }

  final majorEvents = _majorEvents(summary);
  if (majorEvents.isEmpty) {
    return 'No major calendar events in this period.';
  }

  final buffer = StringBuffer('Major Events');
  _writeMajorEvents(buffer, majorEvents);

  if (health != null && health.sleepNightsTracked > 0) {
    _writeEventImpactWindow(buffer, majorEvents, health.dailySleep);
  }

  return buffer.toString().trimRight();
}

void _writeMajorEvents(StringBuffer buffer, List<MajorCalendarEvent> events) {
  for (final event in events) {
    buffer
      ..writeln()
      ..writeln()
      ..writeln(_formatMajorEventDateRange(event.start, event.end))
      ..writeln('- ${event.title}');

    if (event.isHoliday) {
      buffer.writeln('- Duration: ${event.dayCount ?? 1} days');
    } else {
      buffer.writeln(
        '- Overnight travel: ${event.overnightTravel ? 'Yes' : 'No'}',
      );
    }
  }
}

void _writeEventImpactWindow(
  StringBuffer buffer,
  List<MajorCalendarEvent> events,
  List<DailySleepEntry> dailySleep,
) {
  final sections = <String>[];

  for (final event in events) {
    final during = countSleepAnomaliesInWakeDateRange(
      dailySleep,
      event.start,
      event.end,
    );

    if (event.isHoliday) {
      final lateBedtimes = countLateBedtimesInWakeDateRange(
        dailySleep,
        event.start,
        event.end,
      );
      sections.add(
        '${event.impactLabel}:\n'
        '- Sleep anomalies during holiday: $during\n'
        '- Late bedtimes during holiday: $lateBedtimes',
      );
      continue;
    }

    final afterStart = _dateOnly(event.end).add(const Duration(days: 1));
    final afterEnd = _dateOnly(event.end).add(
      const Duration(days: _postEventImpactDays),
    );
    final after = countSleepAnomaliesInWakeDateRange(
      dailySleep,
      afterStart,
      afterEnd,
    );

    sections.add(
      '${event.impactLabel}:\n'
      '- Sleep anomalies during event: $during\n'
      '- Sleep anomalies within $_postEventImpactDays days after: $after',
    );
  }

  if (sections.isEmpty) return;

  buffer
    ..writeln()
    ..writeln()
    ..writeln('Event Impact Window')
    ..writeln()
    ..write(sections.join('\n\n'));
}

List<MajorCalendarEvent> _majorEvents(CalendarSummary summary) {
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
  var blockOvernight = _hasOvernightTravel(qualifying.first);

  for (final event in qualifying.skip(1)) {
    final titleKey = _personalEventKey(event.title);
    final firstDay = _eventFirstDay(event);
    final lastDay = _eventLastInclusiveDay(event);

    if (titleKey == _personalEventKey(blockTitle) &&
        firstDay.difference(blockEnd).inDays == 1) {
      blockEnd = lastDay;
      blockOvernight = blockOvernight || _hasOvernightTravel(event);
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
    blockOvernight = _hasOvernightTravel(event);
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

bool _isMajorPersonalEvent(CalendarEvent event) {
  final first = _eventFirstDay(event);
  final last = _eventLastInclusiveDay(event);
  return last.difference(first).inDays >= 1;
}

bool _hasOvernightTravel(CalendarEvent event) {
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

String _formatMajorEventDateRange(DateTime start, DateTime end) {
  if (start.month == end.month && start.year == end.year) {
    return '${start.day}–${end.day} ${DateFormat('MMM').format(start)}';
  }
  return '${_formatShortDate(start)} – ${_formatShortDate(end)}';
}

String _formatShortDate(DateTime date) =>
    DateFormat('d MMM').format(date.toLocal());

String _impactLabel(String title, {required bool isHoliday}) {
  if (!isHoliday) return title;
  final lower = title.toLowerCase();
  if (lower.contains('eid')) return 'Eid';
  return title;
}

DateTime _dateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);
