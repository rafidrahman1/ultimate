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
  final afterEnd = eventEnd.add(const Duration(days: calendarImpactWindowDays));

  final sleepBefore = includeSleep
      ? _averageSleepInWakeRange(dailySleep, beforeStart, beforeEnd)
      : null;
  final sleepDuring = includeSleep
      ? _averageSleepInWakeRange(dailySleep, eventStart, eventEnd)
      : null;
  final sleepAfter = includeSleep
      ? _averageSleepInWakeRange(dailySleep, afterStart, afterEnd)
      : null;

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

  final hasSpending =
      spendBefore != null || spendDuring != null || spendAfter != null;
  final hasMobility =
      mobilityBefore != null || mobilityDuring != null || mobilityAfter != null;

  if (!includeSleep && !hasSpending && !hasMobility) return null;

  final buffer = StringBuffer(event.impactLabel);
  var wroteSection = false;
  var hasActionableInsight = hasSpending || hasMobility;

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
      if (_sleepSignalIsActionable(sleepBefore, sleepDuring)) {
        hasActionableInsight = true;
      }
    } else {
      buffer.writeln('- Confidence: Insufficient Evidence');
    }
    wroteSection = true;
  }

  if (hasSpending) {
    if (wroteSection) buffer.writeln();
    buffer
      ..writeln('Spending:')
      ..writeln('- Before: ${_formatSpending(spendBefore, expenses?.currency)}')
      ..writeln('- During: ${_formatSpending(spendDuring, expenses?.currency)}')
      ..writeln('- After: ${_formatSpending(spendAfter, expenses?.currency)}');
    hasActionableInsight = true;
    wroteSection = true;
  }

  if (hasMobility) {
    if (wroteSection) buffer.writeln();
    buffer
      ..writeln('Mobility:')
      ..writeln('- Before: ${_formatMobility(mobilityBefore)}')
      ..writeln('- During: ${_formatMobility(mobilityDuring)}')
      ..writeln('- After: ${_formatMobility(mobilityAfter)}');
    hasActionableInsight = true;
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
    hasActionableInsight = true;
  }

  if (!hasActionableInsight) return null;

  return buffer.toString().trimRight();
}

List<String> _impactSummaryLines({
  Duration? sleepBefore,
  Duration? sleepDuring,
  Duration? sleepAfter,
}) {
  final lines = <String>[];
  final disruption =
      sleepDuring != null &&
      sleepBefore != null &&
      sleepDuring.inMinutes < sleepBefore.inMinutes - 15;
  if (disruption) {
    lines.add('Sleep disruption detected');
  }

  final recovered =
      sleepAfter != null &&
      sleepBefore != null &&
      sleepAfter.inMinutes >= sleepBefore.inMinutes - 15;
  if (disruption) {
    lines.add(recovered ? 'Recovered' : 'Not recovered');
  }

  return lines;
}

bool _sleepSignalIsActionable(Duration before, Duration during) {
  final confidence = _sleepImpactConfidence(before, during);
  if (confidence == 'Moderate' || confidence == 'Strong') return true;
  return during.inMinutes < before.inMinutes - 15;
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

  var hasMeaningfulSignal = false;

  if (sleepBefore != null &&
      sleepDuring != null &&
      _sleepSignalIsActionable(sleepBefore, sleepDuring)) {
    hasMeaningfulSignal = true;
  }

  final maxSpend = [spendBefore, spendDuring, spendAfter]
      .whereType<double>()
      .fold<double>(0, (max, value) => value > max ? value : max);
  if (maxSpend >= eventAnalysisMinSpendingBdt) hasMeaningfulSignal = true;

  final maxKm = [mobilityBefore, mobilityDuring, mobilityAfter]
      .whereType<({double km, Duration time})>()
      .fold<double>(0, (max, value) => value.km > max ? value.km : max);
  if (maxKm >= eventAnalysisMinMobilityKm) hasMeaningfulSignal = true;

  return hasMeaningfulSignal;
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

    sections.add(
      '''
Sleep Cluster:
${cluster.label}

Overlap:
${bestOverlap.impactLabel}

Cluster nights overlapping event:
$bestOverlapNights of ${cluster.shortCount}'''
          .trimRight(),
    );
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
      buffer.writeln(
        '- Duration: ${event.dayCount ?? _multiDayCount(event)} days',
      );
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

    final purchases = _purchasesDuring(expenses, period.start, period.end);
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
  if (location == null ||
      !location.hasAnyData ||
      rangeEnd.isBefore(rangeStart)) {
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
