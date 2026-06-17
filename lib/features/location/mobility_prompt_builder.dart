import 'package:intl/intl.dart';

import 'package:personal/core/weekday_schedule.dart';
import 'package:personal/features/analysis/period_comparison.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_metrics.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/work_arrival_stats.dart';
import 'package:personal/features/results/analytics_pipeline_validation.dart';

class MobilityFuelRefuel {
  const MobilityFuelRefuel({
    required this.date,
    required this.amount,
    this.ratePerLitre,
    this.description,
  });

  final DateTime date;
  final double amount;
  final double? ratePerLitre;
  final String? description;
}

class MobilityFuelSummary {
  const MobilityFuelSummary({
    required this.totalSpend,
    required this.refuelCount,
    required this.currency,
    this.refuels = const [],
  });

  final double totalSpend;
  final int refuelCount;
  final String currency;
  final List<MobilityFuelRefuel> refuels;
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
  WorkArrivalStats? previousWorkStats,
  List<DailySleepEntry> dailySleep = const [],
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
    _writeTravel(buffer, travelActivities, weekendDays: weekendDays);
  }

  if (workStats.hasWorkVisits) {
    final attendanceWarnings =
        AnalyticsPipelineValidation.validateWorkAttendance(workStats);
    AnalyticsPipelineValidation.logWarnings('mobility', attendanceWarnings);

    final trend = buildMobilityTrendText(
      current: workStats,
      previous: previousWorkStats,
    );
    if (trend != null) {
      buffer
        ..writeln()
        ..writeln()
        ..write(trend);
    }
    _writeWorkAttendance(buffer, workStats);
  }

  if (workStats.lateArrivals.isNotEmpty) {
    _writeLateArrivals(buffer, workStats);
  }

  if (dailySleep.isNotEmpty && workStats.lateArrivals.isNotEmpty) {
    final correlation = buildLateArrivalCorrelationText(
      workStats: workStats,
      dailySleep: dailySleep,
    );
    if (correlation.isNotEmpty) {
      buffer
        ..writeln()
        ..write(correlation);
    }
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

void _writeTravel(
  StringBuffer buffer,
  List<TimelineActivity> activities, {
  List<int> weekendDays = const [],
}) {
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

  if (weekendDays.isEmpty) return;

  final weekendSet = weekendDays.toSet();
  final distanceByDate = <DateTime, double>{};
  for (final trip in activities) {
    if (!weekendSet.contains(trip.startTime.toLocal().weekday)) continue;
    final local = trip.startTime.toLocal();
    final date = DateTime(local.year, local.month, local.day);
    distanceByDate[date] = (distanceByDate[date] ?? 0) + trip.distanceMeters;
  }
  if (distanceByDate.isEmpty) return;

  buffer.writeln(
    '- Weekend motorcycle (${formatWeekdayList(weekendDays)}):',
  );
  final sortedDates = distanceByDate.keys.toList()..sort();
  for (final date in sortedDates) {
    buffer.writeln(
      '- ${formatMobilityDate(date)}: '
      '${(distanceByDate[date]! / 1000).toStringAsFixed(2)} km',
    );
  }
}

void _writeWorkAttendance(StringBuffer buffer, WorkArrivalStats workStats) {
  buffer
    ..writeln()
    ..writeln('Attendance Summary:')
    ..writeln('- Workdays: ${workStats.totalWorkDays}');

  if (!workStats.hasLateThreshold) return;

  buffer
    ..writeln('- Late arrivals: ${workStats.lateArrivalCount}')
    ..writeln(
      '- Late arrival rate: '
      '${_formatLateArrivalRate(workStats.lateArrivalCount, workStats.totalWorkDays)}',
    );

  final avgDelay = workStats.averageDelayMinutes;
  if (avgDelay != null) {
    buffer.writeln('- Average delay: ${avgDelay.round()} min');
  }
  final worstDelay = workStats.worstDelayMinutes;
  if (worstDelay != null) {
    buffer.writeln('- Worst delay: $worstDelay min');
  }
  if (workStats.lateArrivalCount > 0) {
    buffer.writeln('- Total late minutes: ${workStats.totalLateMinutes}');
  }
}

void _writeLateArrivals(StringBuffer buffer, WorkArrivalStats workStats) {
  buffer
    ..writeln()
    ..writeln('Late Arrival:');

  for (final arrival in workStats.lateArrivals) {
    final scheduled = arrival.scheduledArrival;
    buffer
      ..writeln('- ${formatMobilityDate(arrival.date)}')
      ..writeln(
        '  Scheduled: ${scheduled == null ? 'n/a' : formatMobilityTime(scheduled)}',
      )
      ..writeln('  Actual: ${formatMobilityTime(arrival.arrivalTime)}')
      ..writeln('  Delay: ${arrival.delayMinutes ?? 0} min');
  }
}

String? buildMobilityTrendText({
  required WorkArrivalStats current,
  WorkArrivalStats? previous,
}) {
  final currentRate = current.lateArrivalRate;
  if (currentRate == null) return null;

  final buffer = StringBuffer('Mobility Trend:')
    ..writeln()
    ..writeln(
      '- Current late arrival rate: '
      '${_formatLateArrivalRate(current.lateArrivalCount, current.totalWorkDays)}',
    );

  final previousRate = previous?.lateArrivalRate;
  if (previousRate == null || (previous?.totalWorkDays ?? 0) <= 0) {
    buffer.writeln('- Previous late arrival rate: not available');
    return buffer.toString().trimRight();
  }

  final change = currentRate - previousRate;
  final trend = trendForLowerIsBetter(absoluteChange: change, stableThreshold: 0.5);

  buffer
    ..writeln(
      '- Previous late arrival rate: '
      '${_formatLateArrivalRate(previous!.lateArrivalCount, previous.totalWorkDays)}',
    )
    ..writeln('- Change: ${formatSignedPercentagePointsChange(change)}')
    ..writeln('- Trend: ${formatTrendLabel(trend)}');

  return buffer.toString().trimRight();
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

  final rates = fuel.refuels
      .map((refuel) => refuel.ratePerLitre)
      .whereType<double>()
      .toList();
  if (rates.isNotEmpty) {
    final averageRate = rates.reduce((a, b) => a + b) / rates.length;
    buffer.writeln(
      '- Average fuel rate: '
      '${formatExpenseMoney(averageRate, alwaysTwoDecimals: true)} '
      '${fuel.currency}/L',
    );
  }

  if (fuel.refuels.isEmpty) return;

  buffer.writeln('Refuels:');
  for (final refuel in fuel.refuels) {
    final rateSuffix = refuel.ratePerLitre == null
        ? ''
        : ' @ ${formatExpenseMoney(refuel.ratePerLitre!, alwaysTwoDecimals: true)} '
            '${fuel.currency}/L';
    buffer.writeln(
      '- ${formatMobilityDate(refuel.date)}: '
      '${formatExpenseMoney(refuel.amount, alwaysTwoDecimals: true)} '
      '${fuel.currency}$rateSuffix',
    );
  }
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
  for (final arrival in workStats.lateArrivals) {
    final wakeKey = _wakeDateKey(arrival.date);
    final night = sleepByWakeDate[wakeKey];
    final isShort = night != null &&
        night.session!.duration < sleepTargetDuration;
    if (isShort) precededByShortSleep++;
  }

  final total = workStats.lateArrivals.length;
  final correlation = total > 0 ? precededByShortSleep / total * 100 : 0.0;

  return '''
Sleep-Mobility Correlation:

- Total late arrivals: $total
- Late arrivals preceded by short sleep: $precededByShortSleep
- Correlation: ${(correlation * 10).roundToDouble() / 10}%'''
      .trimRight();
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
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  if (fuelTransactions.isEmpty) return null;

  final refuels = fuelTransactions
      .map(
        (tx) => MobilityFuelRefuel(
          date: tx.date,
          amount: tx.amount.abs(),
          ratePerLitre: ExpensesSummary.fuelRatePerLitreFromDescription(tx),
          description: tx.note?.trim().isNotEmpty == true
              ? tx.note!.trim()
              : tx.title?.trim(),
        ),
      )
      .toList();

  return MobilityFuelSummary(
    totalSpend: refuels.fold(0.0, (sum, refuel) => sum + refuel.amount),
    refuelCount: refuels.length,
    currency: expenses.currency,
    refuels: refuels,
  );
}
