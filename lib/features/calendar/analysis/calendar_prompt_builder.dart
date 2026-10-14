import 'package:intl/intl.dart';

import 'package:personal/features/analysis/period_comparison.dart';
import 'package:personal/features/calendar/data/calendar_event.dart';
import 'package:personal/features/calendar/data/calendar_event_type.dart';
import 'package:personal/features/expenses/analysis/expense_prompt_builder.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/health/analysis/sleep_anomaly.dart';
import 'package:personal/features/health/analysis/sleep_metrics.dart';
import 'package:personal/features/health/analysis/sleep_prompt_builder.dart';
import 'package:personal/features/health/data/health_summary.dart';
import 'package:personal/features/location/data/timeline_activity.dart';

part 'calendar_event_impact_text.dart';
part 'calendar_prompt_helpers.dart';

part 'calendar_event_listing.dart';

const calendarImpactWindowDays = 3;
const eventAnalysisMinSleepDeltaMinutes = 20;
const eventAnalysisMinSpendingBdt = 500;
const eventAnalysisMinMobilityKm = 20;

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

  bool get isTripLike => overnightStay || title.toLowerCase().contains('trip');

  bool get disruptsEveningSleep =>
      timeOfDay == 'Evening' || timeOfDay == 'Night';

  CalendarEventType get eventType =>
      classifyCalendarEvent(title: title, isHoliday: isHoliday);

  String get impactLabel => shortImpactLabel(title, isHoliday: isHoliday);
}

class CalendarPromptOptions {
  const CalendarPromptOptions({
    this.includeFutureEvents = false,
    this.includeEventAnalysis = false,
    this.includeSleepClusterCorrelation = false,
    this.upcomingSource,
    this.upcomingAfter,
    this.health,
    this.location,
    this.expenses,
  });

  final bool includeFutureEvents;
  final bool includeEventAnalysis;
  final bool includeSleepClusterCorrelation;
  final CalendarSummary? upcomingSource;
  final DateTime? upcomingAfter;
  final MonthlyHealthSummary? health;
  final LocationSummary? location;
  final ExpensesSummary? expenses;
}

/// Builds the calendar block for AI analysis: raw events, optional impact
/// metrics, and optional future events (planning runs only).
String buildCalendarPromptText(
  CalendarSummary summary, {
  CalendarSummary? upcomingSource,
  DateTime? upcomingAfter,
  LocationSummary? location,
  ExpensesSummary? expenses,
  MonthlyHealthSummary? health,
  bool includeFutureEvents = false,
  bool includeEventAnalysis = false,
  bool includeSleepClusterCorrelation = false,
}) {
  return buildCalendarAnalysisPromptText(
    summary,
    options: CalendarPromptOptions(
      includeFutureEvents: includeFutureEvents,
      includeEventAnalysis: includeEventAnalysis,
      includeSleepClusterCorrelation: includeSleepClusterCorrelation,
      upcomingSource: upcomingSource,
      upcomingAfter: upcomingAfter,
      health: health,
      location: location,
      expenses: expenses,
    ),
  );
}

String buildCalendarAnalysisPromptText(
  CalendarSummary summary, {
  CalendarPromptOptions options = const CalendarPromptOptions(),
}) {
  final periodEvents = summary.events.isEmpty
      ? const <CalendarPromptEvent>[]
      : listCalendarPromptEvents(summary);

  final futureEvents =
      options.includeFutureEvents &&
          options.upcomingSource != null &&
          options.upcomingSource!.events.isNotEmpty
      ? listUpcomingCalendarPromptEvents(
          options.upcomingSource!,
          after:
              options.upcomingAfter ??
              summary.rangeEnd ??
              (summary.events.isNotEmpty
                  ? summary.events.last.start
                  : DateTime.now()),
        )
      : const <CalendarPromptEvent>[];

  if (periodEvents.isEmpty && futureEvents.isEmpty) {
    return summary.events.isEmpty && options.upcomingSource == null
        ? 'No Google Calendar events synced.'
        : 'No calendar events in this period.';
  }

  final sections = <String>[];

  if (periodEvents.isNotEmpty) {
    final buffer = StringBuffer('Calendar Events');
    _writeRawCalendarEvents(
      buffer,
      periodEvents,
      location: options.location,
      expenses: options.expenses,
    );
    sections.add(buffer.toString().trimRight());
  }

  if (options.includeEventAnalysis && periodEvents.isNotEmpty) {
    final analysis = buildEventAnalysisText(
      periodEvents,
      health: options.health,
      location: options.location,
      expenses: options.expenses,
    );
    if (analysis.isNotEmpty) sections.add(analysis);
  }

  if (options.includeSleepClusterCorrelation &&
      options.health != null &&
      options.health!.sleepNightsTracked > 0 &&
      periodEvents.isNotEmpty) {
    final correlation = buildSleepClusterCorrelationText(
      options.health!.dailySleep,
      periodEvents,
    );
    if (correlation.isNotEmpty) sections.add(correlation);
  }

  if (futureEvents.isNotEmpty) {
    final buffer = StringBuffer('Future Events');
    _writeRawCalendarEvents(buffer, futureEvents);
    sections.add(buffer.toString().trimRight());
  }

  return sections.join('\n\n');
}
