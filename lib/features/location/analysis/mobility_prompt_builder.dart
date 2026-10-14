import 'package:intl/intl.dart';

import 'package:personal/core/formatting.dart';
import 'package:personal/core/schedule/weekday_schedule.dart';
import 'package:personal/features/analysis/period_comparison.dart';
import 'package:personal/features/expenses/analysis/expense_prompt_builder.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/health/analysis/sleep_metrics.dart';
import 'package:personal/features/health/data/health_summary.dart';
import 'package:personal/features/location/analysis/place_stats.dart';
import 'package:personal/features/location/analysis/work_arrival_stats.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_profile.dart';
import 'package:personal/features/results/pipeline/analytics_pipeline_validation.dart';

part 'mobility_prompt_sections.dart';
part 'mobility_trend_and_fuel_text.dart';

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

  /// Refuels whose description carried a usable price per litre.
  List<MobilityFuelRefuel> get pricedRefuels =>
      refuels.where((refuel) => (refuel.ratePerLitre ?? 0) > 0).toList();

  /// Litres bought (amount ÷ rate), summed over refuels with a known rate.
  double? get totalLitres {
    final priced = pricedRefuels;
    if (priced.isEmpty) return null;
    return priced.fold<double>(
      0,
      (sum, refuel) => sum + refuel.amount / refuel.ratePerLitre!,
    );
  }

  /// Volume-weighted price per litre across priced refuels.
  double? get weightedRatePerLitre {
    final litres = totalLitres;
    if (litres == null || litres <= 0) return null;
    final pricedSpend = pricedRefuels.fold<double>(
      0,
      (sum, refuel) => sum + refuel.amount,
    );
    return pricedSpend / litres;
  }
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
  LocationInsights? previousInsights,
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

  final insights = summary.insights;
  if (insights != null && insights.hasData) {
    _writePlacesAndTime(
      buffer,
      insights,
      previous: previousInsights,
      names: summary.placeNames,
    );
  }

  if (summary.trips.isNotEmpty) {
    _writeTripsAway(buffer, summary.trips);
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
