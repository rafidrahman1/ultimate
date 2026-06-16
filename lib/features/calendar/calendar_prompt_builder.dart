import 'package:intl/intl.dart';

import 'package:personal/features/analysis/period_comparison.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_event_type.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_anomaly.dart';
import 'package:personal/features/health/sleep_metrics.dart';
import 'package:personal/features/health/sleep_prompt_builder.dart';
import 'package:personal/features/location/timeline_activity.dart';

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

  CalendarEventType get eventType =>
      classifyCalendarEvent(title: title, isHoliday: isHoliday);

  String get impactLabel =>
      shortImpactLabel(title, isHoliday: isHoliday);
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

  final futureEvents = options.includeFutureEvents &&
          options.upcomingSource != null &&
          options.upcomingSource!.events.isNotEmpty
      ? listUpcomingCalendarPromptEvents(
          options.upcomingSource!,
          after: options.upcomingAfter ??
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

String buildEventAnalysisText(
  List<CalendarPromptEvent> events, {
  MonthlyHealthSummary? health,
  LocationSummary? location,
  ExpensesSummary? expenses,
}) {
  if (events.isEmpty) return '';

  final hasHealth = health != null && health.sleepNightsTracked > 0;
  final eventSections = <String>[];

  for (final event in events) {
    final block = _eventAnalysisBlock(
      event,
      dailySleep: hasHealth ? health.dailySleep : const [],
      location: location,
      expenses: expenses,
      includeSleep: hasHealth,
    );
    if (block != null) eventSections.add(block);
  }

  if (eventSections.isEmpty) return '';

  return 'Event Analysis\n\n${eventSections.join('\n\n')}';
}

String? _eventAnalysisBlock(
  CalendarPromptEvent event, {
  required List<DailySleepEntry> dailySleep,
  LocationSummary? location,
  ExpensesSummary? expenses,
  required bool includeSleep,
}) {
  final eventStart = _dateOnly(event.start);
  final eventEnd = _dateOnly(event.end);
  final beforeStart = eventStart.subtract(
    const Duration(days: calendarImpactWindowDays),
  );
  final beforeEnd = eventStart.subtract(const Duration(days: 1));
  final afterStart = eventEnd.add(const Duration(days: 1));
  final afterEnd = eventEnd.add(
    const Duration(days: calendarImpactWindowDays),
  );

  final sleepBefore =
      includeSleep ? _averageSleepInWakeRange(dailySleep, beforeStart, beforeEnd) : null;
  final sleepDuring =
      includeSleep ? _averageSleepInWakeRange(dailySleep, eventStart, eventEnd) : null;
  final sleepAfter =
      includeSleep ? _averageSleepInWakeRange(dailySleep, afterStart, afterEnd) : null;

  final spendBefore = _spendingInRange(expenses, beforeStart, beforeEnd);
  final spendDuring = _spendingInRange(expenses, eventStart, eventEnd);
  final spendAfter = _spendingInRange(expenses, afterStart, afterEnd);

  final mobilityBefore = _mobilityInRange(location, beforeStart, beforeEnd);
  final mobilityDuring = _mobilityInRange(location, eventStart, eventEnd);
  final mobilityAfter = _mobilityInRange(location, afterStart, afterEnd);

  if (!_eventQualifiesForAnalysis(
    event: event,
    sleepBefore: sleepBefore,
    sleepDuring: sleepDuring,
    spendBefore: spendBefore,
    spendDuring: spendDuring,
    spendAfter: spendAfter,
    mobilityBefore: mobilityBefore,
    mobilityDuring: mobilityDuring,
    mobilityAfter: mobilityAfter,
  )) {
    return null;
  }

  final hasSpending = spendBefore != null ||
      spendDuring != null ||
      spendAfter != null;
  final hasMobility = mobilityBefore != null ||
      mobilityDuring != null ||
      mobilityAfter != null;

  if (!includeSleep && !hasSpending && !hasMobility) return null;

  final buffer = StringBuffer(event.impactLabel);
  var wroteSection = false;

  if (includeSleep) {
    buffer
      ..writeln()
      ..writeln()
      ..writeln('Sleep:')
      ..writeln('- Before: ${_formatSleepAverage(sleepBefore)}')
      ..writeln('- During: ${_formatSleepAverage(sleepDuring)}')
      ..writeln('- After: ${_formatSleepAverage(sleepAfter)}');
    if (sleepBefore != null && sleepDuring != null) {
      final deltaMinutes = sleepDuring.inMinutes - sleepBefore.inMinutes;
      buffer
        ..writeln(
          '- Difference: ${formatSignedDurationChange(Duration(minutes: deltaMinutes))}',
        )
        ..writeln(
          '- Confidence: ${_sleepImpactConfidence(sleepBefore, sleepDuring)}',
        );
    } else {
      buffer.writeln('- Confidence: Insufficient Evidence');
    }
    wroteSection = true;
  }

  if (hasSpending) {
    if (wroteSection) buffer.writeln();
    buffer
      ..writeln('Spending:')
      ..writeln(
        '- Before: ${_formatSpending(spendBefore, expenses?.currency)}',
      )
      ..writeln(
        '- During: ${_formatSpending(spendDuring, expenses?.currency)}',
      )
      ..writeln(
        '- After: ${_formatSpending(spendAfter, expenses?.currency)}',
      );
    wroteSection = true;
  }

  if (hasMobility) {
    if (wroteSection) buffer.writeln();
    buffer
      ..writeln('Mobility:')
      ..writeln('- Before: ${_formatMobility(mobilityBefore)}')
      ..writeln('- During: ${_formatMobility(mobilityDuring)}')
      ..writeln('- After: ${_formatMobility(mobilityAfter)}');
    wroteSection = true;
  }

  final impactLines = _impactSummaryLines(
    sleepBefore: sleepBefore,
    sleepDuring: sleepDuring,
    sleepAfter: sleepAfter,
  );
  if (impactLines.isNotEmpty) {
    if (wroteSection) buffer.writeln();
    buffer.writeln('Impact:');
    for (final line in impactLines) {
      buffer.writeln('- $line');
    }
  }

  return buffer.toString().trimRight();
}

List<String> _impactSummaryLines({
  Duration? sleepBefore,
  Duration? sleepDuring,
  Duration? sleepAfter,
}) {
  final lines = <String>[];
  final disruption = sleepDuring != null &&
      sleepBefore != null &&
      sleepDuring.inMinutes < sleepBefore.inMinutes - 15;
  if (disruption) {
    lines.add('Sleep disruption detected');
  }

  final recovered = sleepAfter != null &&
      sleepBefore != null &&
      sleepAfter.inMinutes >= sleepBefore.inMinutes - 15;
  if (disruption) {
    lines.add(recovered ? 'Recovered' : 'Not recovered');
  }

  return lines;
}

String _sleepImpactConfidence(Duration before, Duration during) {
  final deltaMinutes = (during.inMinutes - before.inMinutes).abs();
  if (deltaMinutes >= 60) return 'Strong';
  if (deltaMinutes >= 30) return 'Moderate';
  if (deltaMinutes >= 15) return 'Weak';
  return 'Insufficient Evidence';
}

bool _eventQualifiesForAnalysis({
  required CalendarPromptEvent event,
  Duration? sleepBefore,
  Duration? sleepDuring,
  double? spendBefore,
  double? spendDuring,
  double? spendAfter,
  ({double km, Duration time})? mobilityBefore,
  ({double km, Duration time})? mobilityDuring,
  ({double km, Duration time})? mobilityAfter,
}) {
  if (_eventDurationDays(event) > 1) return true;

  if (sleepBefore != null && sleepDuring != null) {
    final deltaMinutes = (sleepDuring.inMinutes - sleepBefore.inMinutes).abs();
    if (deltaMinutes >= eventAnalysisMinSleepDeltaMinutes) return true;
  }

  final maxSpend = [
    spendBefore,
    spendDuring,
    spendAfter,
  ].whereType<double>().fold<double>(0, (max, value) => value > max ? value : max);
  if (maxSpend >= eventAnalysisMinSpendingBdt) return true;

  final maxKm = [
    mobilityBefore,
    mobilityDuring,
    mobilityAfter,
  ].whereType<({double km, Duration time})>().fold<double>(
    0,
    (max, value) => value.km > max ? value.km : max,
  );
  if (maxKm >= eventAnalysisMinMobilityKm) return true;

  return false;
}

int _eventDurationDays(CalendarPromptEvent event) {
  return _dateOnly(event.end).difference(_dateOnly(event.start)).inDays + 1;
}

String buildSleepClusterCorrelationText(
  List<DailySleepEntry> dailySleep,
  List<CalendarPromptEvent> events,
) {
  final clusters = detectSleepClusters(dailySleep);
  if (clusters.isEmpty) return '';

  final sections = <String>[];
  for (final cluster in clusters) {
    CalendarPromptEvent? bestOverlap;
    var bestOverlapNights = 0;

    for (final event in events) {
      final overlapNights = _clusterNightsOverlappingEvent(
        dailySleep: dailySleep,
        clusterStart: cluster.start,
        clusterEnd: cluster.end,
        eventStart: _dateOnly(event.start),
        eventEnd: _dateOnly(event.end),
      );
      if (overlapNights > bestOverlapNights) {
        bestOverlapNights = overlapNights;
        bestOverlap = event;
      }
    }

    if (bestOverlap == null || bestOverlapNights <= 0) continue;

    sections.add('''
Sleep Cluster:
${cluster.label}

Overlap:
${bestOverlap.impactLabel}

Cluster nights overlapping event:
$bestOverlapNights of ${cluster.shortCount}'''
        .trimRight());
  }

  if (sections.isEmpty) return '';
  return 'Sleep Cluster Correlation\n\n${sections.join('\n\n')}';
}

int _clusterNightsOverlappingEvent({
  required List<DailySleepEntry> dailySleep,
  required DateTime clusterStart,
  required DateTime clusterEnd,
  required DateTime eventStart,
  required DateTime eventEnd,
}) {
  return dailySleep
      .where(
        (night) =>
            night.hasData &&
            isSleepAnomalyNight(night) &&
            !_dateOnly(night.wakeDate).isBefore(clusterStart) &&
            !_dateOnly(night.wakeDate).isAfter(clusterEnd) &&
            !_dateOnly(night.wakeDate).isBefore(eventStart) &&
            !_dateOnly(night.wakeDate).isAfter(eventEnd),
      )
      .length;
}

@Deprecated('Use buildEventAnalysisText via buildCalendarAnalysisPromptText')
String buildCalendarImpactDerivedText(
  CalendarSummary summary, {
  MonthlyHealthSummary? health,
  ExpensesSummary? expenses,
}) {
  if (summary.events.isEmpty) return '';
  return buildEventAnalysisText(
    listCalendarPromptEvents(summary),
    health: health,
    expenses: expenses,
  );
}

void _writeRawCalendarEvents(
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
      ..writeln('- ${event.title}')
      ..writeln('- Type: ${event.eventType.label}');

    if (event.isHoliday && event.isMultiDay) {
      buffer.writeln('- Duration: ${event.dayCount ?? _multiDayCount(event)} days');
    }

    if (event.overnightStay) {
      buffer.writeln('- Overnight stay: Yes');
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

int _multiDayCount(CalendarPromptEvent event) {
  return _dateOnly(event.end).difference(_dateOnly(event.start)).inDays + 1;
}

Duration? _averageSleepInWakeRange(
  List<DailySleepEntry> dailySleep,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  if (rangeEnd.isBefore(rangeStart)) return null;

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
  if (expenses == null || rangeEnd.isBefore(rangeStart)) return null;

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

({double km, Duration time})? _mobilityInRange(
  LocationSummary? location,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  if (location == null || !location.hasAnyData || rangeEnd.isBefore(rangeStart)) {
    return null;
  }

  final trips = _motorcycleTripsDuring(
    location,
    _dateOnly(rangeStart),
    _endOfDay(_dateOnly(rangeEnd)),
  );
  if (trips.isEmpty) return null;

  final distanceMeters = trips.fold(
    0.0,
    (sum, trip) => sum + trip.distanceMeters,
  );
  final travelTime = trips.fold(
    Duration.zero,
    (sum, trip) => sum + trip.duration,
  );
  return (km: distanceMeters / 1000, time: travelTime);
}

String _formatSleepAverage(Duration? duration) {
  if (duration == null) return 'no data';
  return formatDurationPadded(duration);
}

String _formatSpending(double? amount, String? currency) {
  if (amount == null) return 'no data';
  final label = formatExpenseMoney(amount, alwaysTwoDecimals: true);
  if (currency == null || currency.isEmpty) return label;
  return '$label $currency';
}

String _formatMobility(({double km, Duration time})? metrics) {
  if (metrics == null) return 'no data';
  if (metrics.time > Duration.zero) {
    return '${metrics.km.toStringAsFixed(2)} km · '
        '${formatTravelDuration(metrics.time)}';
  }
  return '${metrics.km.toStringAsFixed(2)} km';
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
