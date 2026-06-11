import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/core/period_range.dart';
import 'package:personal/features/calendar/calendar_holiday_groups.dart';

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
    this.accountDisplayName,
    this.accountPhotoUrl,
    this.syncedAt,
    this.rangeStart,
    this.rangeEnd,
  });

  final List<CalendarEvent> events;
  final String? accountEmail;
  final String? accountDisplayName;
  final String? accountPhotoUrl;
  final DateTime? syncedAt;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  /// Events within the analysis data month.
  CalendarSummary forAnalysisPeriod(AnalysisPeriod period) {
    return forEventRange(
      start: period.dataMonthStart,
      end: period.dataMonthEnd,
    );
  }

  /// Events within the Google Calendar sync window (analysis month + next month).
  CalendarSummary forSyncedDisplayRange(DateTime analysisMonthStart) {
    final range = monthAndNextMonthRange(analysisMonthStart);
    return forEventRange(start: range.start, end: range.end);
  }

  CalendarSummary forEventRange({
    required DateTime start,
    required DateTime end,
  }) {
    final filtered = events
        .where((event) => isDateInRange(event.start, start, end))
        .toList();
    return CalendarSummary(
      events: filtered,
      accountEmail: accountEmail,
      accountDisplayName: accountDisplayName,
      accountPhotoUrl: accountPhotoUrl,
      syncedAt: syncedAt,
      rangeStart: start,
      rangeEnd: end,
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

    return '${periodLine}Events:\n${lines.join('\n')}';
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
