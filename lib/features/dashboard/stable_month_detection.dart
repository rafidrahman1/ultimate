import 'package:personal/core/formatting.dart';
import 'package:personal/features/analysis/analysis_source_selection.dart';
import 'package:personal/features/calendar/calendar_event_summary.dart';
import 'package:personal/features/dashboard/anomaly_ranking.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_anomaly.dart';
import 'package:personal/features/health/sleep_metrics.dart';
import 'package:personal/features/location/work_arrival_stats.dart';

const stableMonthMaxShortSleepNights = 2;
const stableMonthMaxSleepDebt = Duration(hours: 5);
const stableMonthMaxCategoryIncomeShare = 0.10;
const severeAnomalyMinSeverity = 8;
const severeSleepClusterMinShortNights = 5;
const severeSleepStreakMinNights = 4;

class StableMonthAssessment {
  const StableMonthAssessment({
    required this.isStable,
    required this.canEvaluate,
    required this.shortSleepNights,
    required this.sleepDebt,
    this.largestCategoryName,
    this.largestCategorySpendingShare,
    required this.hasSevereAnomalyCluster,
    this.severeClusterLabel,
  });

  final bool isStable;
  final bool canEvaluate;
  final int shortSleepNights;
  final Duration sleepDebt;
  final String? largestCategoryName;
  final double? largestCategorySpendingShare;
  final bool hasSevereAnomalyCluster;
  final String? severeClusterLabel;
}

StableMonthAssessment evaluateStableMonth({
  required AnalysisSourceSelection selection,
  required List<DailySleepEntry> dailySleep,
  ExpensesSummary? expenses,
  List<MajorCalendarEvent> calendarEvents = const [],
  WorkArrivalStats? workStats,
}) {
  final hasHealth =
      selection.includes(AnalysisDataSourceId.health) &&
      dailySleep.any((night) => night.hasData);
  final hasExpenses =
      selection.includes(AnalysisDataSourceId.expenses) &&
      expenses != null &&
      expenses.transactions.isNotEmpty;

  if (!hasHealth || !hasExpenses) {
    return StableMonthAssessment(
      isStable: false,
      canEvaluate: false,
      shortSleepNights: 0,
      sleepDebt: Duration.zero,
      hasSevereAnomalyCluster: false,
    );
  }

  final nightsWithData = dailySleep.where((night) => night.hasData).toList();
  final shortSleepNights = nightsWithData.where(isSleepAnomalyNight).length;
  final sleepDebt = computeSleepDebt(nightsWithData).estimatedDebt;

  String? largestCategoryName;
  double? largestCategorySpendingShare;
  var categoryWithinLimit = true;
  final totalSpent = expenses.totalRealExpenses;
  final incomeBaseline = expenses.totalIncome;
  if (expenses.expensesByCategory.isNotEmpty) {
    final top = expenses.expensesByCategory.first;
    largestCategoryName = top.category;
    largestCategorySpendingShare = totalSpent > 0
        ? top.total / totalSpent
        : null;
    final incomeShare = incomeBaseline > 0 ? top.total / incomeBaseline : null;
    categoryWithinLimit = incomeShare == null
        ? true
        : incomeShare <= stableMonthMaxCategoryIncomeShare;
  }

  final severeCluster = _findSevereAnomalyCluster(
    dailySleep: nightsWithData,
    expenses: expenses,
    calendarEvents: calendarEvents,
    workStats: workStats,
  );

  final isStable =
      shortSleepNights <= stableMonthMaxShortSleepNights &&
      sleepDebt < stableMonthMaxSleepDebt &&
      categoryWithinLimit &&
      !severeCluster.hasSevere;

  return StableMonthAssessment(
    isStable: isStable,
    canEvaluate: true,
    shortSleepNights: shortSleepNights,
    sleepDebt: sleepDebt,
    largestCategoryName: largestCategoryName,
    largestCategorySpendingShare: largestCategorySpendingShare,
    hasSevereAnomalyCluster: severeCluster.hasSevere,
    severeClusterLabel: severeCluster.label,
  );
}

String buildHealthyMonthDetectionText(StableMonthAssessment assessment) {
  if (!assessment.canEvaluate) {
    return 'Month: n/a (health + expenses required)';
  }

  final debtLabel = formatDebtDuration(assessment.sleepDebt);
  final categoryShareLabel = assessment.largestCategorySpendingShare == null
      ? 'n/a'
      : '${formatPercent1dp(assessment.largestCategorySpendingShare! * 100)} of spending';
  final severeLabel = assessment.hasSevereAnomalyCluster
      ? assessment.severeClusterLabel ?? 'yes'
      : 'none';

  return '''
Month: ${assessment.isStable ? 'Stable' : 'Active'}
Short sleep nights: ${assessment.shortSleepNights}
Sleep debt: $debtLabel
Top category: ${assessment.largestCategoryName ?? 'none'} · $categoryShareLabel
Severe cluster: $severeLabel'''
      .trimRight();
}

({bool hasSevere, String? label}) _findSevereAnomalyCluster({
  required List<DailySleepEntry> dailySleep,
  required ExpensesSummary expenses,
  List<MajorCalendarEvent> calendarEvents = const [],
  WorkArrivalStats? workStats,
}) {
  for (final cluster in detectSleepClusters(dailySleep)) {
    final isSevere =
        cluster.shortCount >= severeSleepClusterMinShortNights ||
        (cluster.isConsecutiveStreak &&
            cluster.shortCount >= severeSleepStreakMinNights);
    if (isSevere) {
      return (hasSevere: true, label: cluster.rankingLabel);
    }
  }

  final ranking = buildAnomalyCandidates(
    dailySleep: dailySleep,
    expenses: expenses,
    calendarEvents: calendarEvents,
    workStats: workStats,
  );
  final topCandidate = highestSeverityCandidate(ranking);
  if (topCandidate != null &&
      topCandidate.severity >= severeAnomalyMinSeverity) {
    return (hasSevere: true, label: topCandidate.label);
  }

  return (hasSevere: false, label: null);
}
