import '../../core/analysis_period.dart';
import '../../core/period_range.dart';
import 'calendar_holiday_groups.dart';

class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    this.location,
    this.isHoliday = false,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? location;
  final bool isHoliday;
}

class CalendarSummary {
  const CalendarSummary({
    required this.events,
    this.accountEmail,
    this.syncedAt,
    this.rangeStart,
    this.rangeEnd,
  });

  final List<CalendarEvent> events;
  final String? accountEmail;
  final DateTime? syncedAt;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  /// Past month events plus the upcoming checklist month.
  CalendarSummary forAnalysisPeriod(AnalysisPeriod period) {
    final checklistEnd = calendarMonthRange(period.checklistMonthStart).end;
    final filtered = events
        .where(
          (event) => isDateInRange(
            event.start,
            period.dataMonthStart,
            checklistEnd,
          ),
        )
        .toList();
    return CalendarSummary(
      events: filtered,
      accountEmail: accountEmail,
      syncedAt: syncedAt,
      rangeStart: period.dataMonthStart,
      rangeEnd: checklistEnd,
    );
  }

  List<CalendarEvent> get sortedByStart {
    final copy = List<CalendarEvent>.from(events);
    copy.sort((a, b) => a.start.compareTo(b.start));
    return copy;
  }

  List<CalendarTimelineEntry> get timeline => buildCalendarTimeline(events);

  List<CalendarHolidayGroup> get holidayGroups =>
      groupConsecutiveHolidays(events);

  List<CalendarEvent> get upcomingEvents {
    final now = DateTime.now();
    return sortedByStart.where((event) => !event.end.isBefore(now)).toList();
  }

  int get allDayCount => events.where((event) => event.allDay).length;

  int get holidayCount => events.where((event) => event.isHoliday).length;

  int get holidayGroupCount => holidayGroups.length;

  String? get periodRangeLabel {
    if (rangeStart == null || rangeEnd == null) return null;
    return formatPeriodRange(rangeStart!, rangeEnd!);
  }

  String toAnalysisPromptText() {
    if (events.isEmpty) {
      return 'No Google Calendar events synced.';
    }

    final period = periodRangeLabel;
    final periodLine =
        period != null ? 'Period: $period\n' : 'Period: unknown\n';
    final accountLine = accountEmail == null
        ? ''
        : 'Account: $accountEmail\n';

    final lines = <String>[];
    String? lastDate;
    for (final entry in timeline) {
      switch (entry) {
        case CalendarHolidayGroupEntry(:final group):
          lines.add(formatHolidayGroupForPrompt(group));
          lastDate = null;
        case CalendarPersonalEntry(:final event):
          final date = _dateKey(event.start);
          final showDate = date != lastDate;
          lastDate = date;
          final timeLabel = event.allDay
              ? 'all day'
              : '${_timeKey(event.start)}–${_timeKey(event.end)}';
          final locationSuffix =
              event.location == null || event.location!.isEmpty
                  ? ''
                  : ' @ ${event.location}';
          if (showDate) {
            lines.add('  - $date · ${event.title} ($timeLabel)$locationSuffix');
          } else {
            lines.add('  - ${event.title} ($timeLabel)$locationSuffix');
          }
      }
    }

    final holidayLine = holidayCount > 0
        ? ', $holidayGroupCount Bangladesh public holidays '
            '($holidayCount days)'
        : '';
    return '$periodLine$accountLine'
        'Events: ${events.length} (${upcomingEvents.length} upcoming, '
        '$allDayCount all-day$holidayLine)\n'
        '${lines.join('\n')}';
  }

  static String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String _timeKey(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
