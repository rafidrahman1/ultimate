import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/core/period_range.dart';
import 'package:personal/features/calendar/calendar_holiday_groups.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/location/timeline_activity.dart';

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

  String toAnalysisPromptText({
    MonthlyHealthSummary? health,
    CalendarSummary? upcomingSource,
    DateTime? upcomingAfter,
    LocationSummary? location,
    ExpensesSummary? expenses,
    bool includeFutureEvents = false,
    bool includeEventAnalysis = false,
    bool includeSleepClusterCorrelation = false,
  }) =>
      buildCalendarPromptText(
        this,
        upcomingSource: upcomingSource,
        upcomingAfter: upcomingAfter,
        location: location,
        expenses: expenses,
        health: health,
        includeFutureEvents: includeFutureEvents,
        includeEventAnalysis: includeEventAnalysis,
        includeSleepClusterCorrelation: includeSleepClusterCorrelation,
      );
}
