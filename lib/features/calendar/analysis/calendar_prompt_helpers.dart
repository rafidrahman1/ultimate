part of 'calendar_prompt_builder.dart';

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
