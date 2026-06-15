import 'package:intl/intl.dart';

import 'package:personal/core/weekday_schedule.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_metrics.dart';
import 'package:personal/features/health/sleep_prompt_builder.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/work_arrival_stats.dart';

class MobilityFuelSummary {
  const MobilityFuelSummary({
    required this.totalSpend,
    required this.refuelCount,
    required this.currency,
  });

  final double totalSpend;
  final int refuelCount;
  final String currency;
}

String buildMobilityPromptText({
  required LocationSummary summary,
  DateTime? referenceDate,
  DateTime? dataMonthStart,
  DateTime? dataMonthEnd,
  String workAddress = '',
  String workHours = '',
  List<int> weekendDays = const [],
  MobilityFuelSummary? fuel,
}) {
  if (!summary.hasAnyData) return 'No location timeline data imported.';

  final travelActivities = _travelActivities(
    summary: summary,
    referenceDate: referenceDate,
    dataMonthStart: dataMonthStart,
    dataMonthEnd: dataMonthEnd,
  );
  final visits = dataMonthStart != null && dataMonthEnd != null
      ? summary.placeVisitsInRange(dataMonthStart, dataMonthEnd)
      : summary.placeVisits;
  final workStats = WorkArrivalStats.analyze(
    placeVisits: visits,
    workAddress: workAddress,
    workHours: workHours,
  );

  final buffer = StringBuffer('Mobility Summary');

  if (travelActivities.isNotEmpty) {
    _writeTravel(buffer, travelActivities);
  }

  if (weekendDays.isNotEmpty) {
    _writeWeekendMotorcycle(buffer, summary, weekendDays);
  }

  if (workStats.hasWorkVisits) {
    _writeWorkAttendance(buffer, workStats);
  }

  if (workStats.lateArrivals.isNotEmpty) {
    _writeLateArrivals(buffer, workStats.lateArrivals);
  }

  if (fuel != null) {
    _writeFuel(buffer, fuel);
  }

  final text = buffer.toString().trimRight();
  if (text == 'Mobility Summary') {
    return 'No mobility data found in this period.';
  }

  return text;
}

List<TimelineActivity> _travelActivities({
  required LocationSummary summary,
  DateTime? referenceDate,
  DateTime? dataMonthStart,
  DateTime? dataMonthEnd,
}) {
  final activities = dataMonthStart != null && dataMonthEnd != null
      ? summary.activitiesInRange(dataMonthStart, dataMonthEnd)
      : summary.activitiesInMonthToDate(referenceDate: referenceDate);

  return activities
      .where(
        (activity) => activity.isMotorcycling && activity.distanceMeters > 0,
      )
      .toList();
}

void _writeTravel(StringBuffer buffer, List<TimelineActivity> activities) {
  final distanceMeters = activities.fold(
    0.0,
    (sum, activity) => sum + activity.distanceMeters,
  );
  final travelTime = activities.fold(
    Duration.zero,
    (sum, activity) => sum + activity.duration,
  );

  buffer
    ..writeln()
    ..writeln()
    ..writeln('Travel:')
    ..writeln('- Distance: ${(distanceMeters / 1000).toStringAsFixed(2)} km')
    ..writeln('- Travel Time: ${formatTravelDuration(travelTime)}');
}

void _writeWeekendMotorcycle(
  StringBuffer buffer,
  LocationSummary summary,
  List<int> weekendDays,
) {
  final activities = summary.periodMotorcycleActivitiesOnWeekendDays(weekendDays);
  final distanceMeters = summary.periodMotorcycleDistanceMetersOnWeekendDays(
    weekendDays,
  );
  final travelTime = activities.fold(
    Duration.zero,
    (sum, activity) => sum + activity.duration,
  );

  buffer
    ..writeln()
    ..writeln()
    ..writeln('Weekend Motorcycle:')
    ..writeln('- Weekend days: ${formatWeekdayList(weekendDays)}')
    ..writeln('- Distance: ${(distanceMeters / 1000).toStringAsFixed(2)} km')
    ..writeln('- Trips: ${activities.length}')
    ..writeln('- Travel Time: ${formatTravelDuration(travelTime)}');
}

void _writeWorkAttendance(StringBuffer buffer, WorkArrivalStats workStats) {
  buffer
    ..writeln()
    ..writeln('Work Attendance:')
    ..writeln('- Workdays: ${workStats.totalWorkDays}');

  if (!workStats.hasLateThreshold) return;

  buffer
    ..writeln('- Late arrivals: ${workStats.lateArrivalCount}')
    ..writeln(
      '- Late arrival rate: '
      '${_formatLateArrivalRate(workStats.lateArrivalCount, workStats.totalWorkDays)}',
    );
}

void _writeLateArrivals(StringBuffer buffer, List<WorkDayArrival> lateArrivals) {
  buffer
    ..writeln()
    ..writeln('Late Arrivals:');

  for (final arrival in lateArrivals) {
    buffer.writeln(
      '- ${formatMobilityDate(arrival.date)}: '
      '${formatMobilityTime(arrival.arrivalTime)}',
    );
  }
}

void _writeFuel(StringBuffer buffer, MobilityFuelSummary fuel) {
  buffer
    ..writeln()
    ..writeln('Fuel:')
    ..writeln(
      '- Total fuel spend: ${formatExpenseMoney(fuel.totalSpend)} '
      '${fuel.currency}',
    )
    ..writeln('- Refuels: ${fuel.refuelCount}');
}

String _formatLateArrivalRate(int lateArrivals, int workdays) {
  if (workdays <= 0) return '0.0%';
  final percent = lateArrivals / workdays * 100;
  return '${((percent * 10).roundToDouble() / 10).toStringAsFixed(1)}%';
}

String formatMobilityDate(DateTime date) =>
    DateFormat('d MMM').format(date.toLocal());

String formatMobilityTime(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String buildLateArrivalCorrelationText({
  required WorkArrivalStats workStats,
  required List<DailySleepEntry> dailySleep,
}) {
  if (workStats.lateArrivals.isEmpty) return '';

  final sleepByWakeDate = {
    for (final night in dailySleep.where((night) => night.hasData))
      _wakeDateKey(night.wakeDate): night,
  };

  var precededByShortSleep = 0;
  final buffer = StringBuffer('Late Arrival Correlation');

  for (final arrival in workStats.lateArrivals) {
    final wakeKey = _wakeDateKey(arrival.date);
    final night = sleepByWakeDate[wakeKey];
    final sleepLabel = night == null
        ? 'no data'
        : formatDurationCompact(night.session!.duration);
    final isShort = night != null &&
        night.session!.duration < sleepTargetDuration;
    if (isShort) precededByShortSleep++;

    buffer
      ..writeln()
      ..writeln()
      ..writeln(formatMobilityDate(arrival.date))
      ..writeln('Sleep previous night: $sleepLabel');
  }

  buffer
    ..writeln()
    ..writeln(
      'Late arrivals preceded by short sleep:\n'
      '$precededByShortSleep of ${workStats.lateArrivals.length}',
    );

  return buffer.toString().trimRight();
}

String _wakeDateKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month}-${local.day}';
}

MobilityFuelSummary? mobilityFuelSummaryFromExpenses(
  ExpensesSummary expenses,
) {
  final fuelTransactions = expenses.transactions
      .where((tx) => tx.isRealExpense && ExpensesSummary.isFuelExpense(tx))
      .toList();
  if (fuelTransactions.isEmpty) return null;

  return MobilityFuelSummary(
    totalSpend: fuelTransactions.fold(
      0.0,
      (sum, tx) => sum + tx.amount.abs(),
    ),
    refuelCount: fuelTransactions.length,
    currency: expenses.currency,
  );
}
