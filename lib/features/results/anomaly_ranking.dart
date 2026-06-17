import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_anomaly_filter.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_metrics.dart';
import 'package:personal/features/location/work_arrival_stats.dart';
import 'package:personal/features/progress_review/progress_review_evaluation.dart';

const spendingClusterMinSpendingShare = 0.2;
const spendingClusterIncomeShareSuppressThreshold = 0.15;
const spendingClusterReducedSeverityCap = 3;
const attendanceLateRateWorseningThreshold = 5.0;
const attendanceSleepCorrelationBoostThreshold = 40.0;

class AnomalyCandidate {
  const AnomalyCandidate({
    required this.label,
    required this.severity,
    required this.recurrence,
    required this.crossDomain,
    this.priorityTier = 7,
  });

  final String label;
  final int severity;
  final int recurrence;
  final int crossDomain;
  final int priorityTier;

  int get impactScore => (severity * 5) + (recurrence * 3) + (crossDomain * 2);
}

bool isSignificantAnomaly(AnomalyCandidate candidate) => candidate.severity > 0;

List<AnomalyCandidate> rankAnomalyCandidates(List<AnomalyCandidate> candidates) {
  final ranked =
      candidates.where((candidate) => candidate.severity > 0).toList()
        ..sort((a, b) {
          final tierCompare = a.priorityTier.compareTo(b.priorityTier);
          if (tierCompare != 0) return tierCompare;
          final scoreCompare = b.impactScore.compareTo(a.impactScore);
          if (scoreCompare != 0) return scoreCompare;
          final recurrenceCompare = b.recurrence.compareTo(a.recurrence);
          if (recurrenceCompare != 0) return recurrenceCompare;
          return b.crossDomain.compareTo(a.crossDomain);
        });
  return ranked;
}

List<AnomalyCandidate> buildAnomalyCandidates({
  List<DailySleepEntry> dailySleep = const [],
  ExpensesSummary? expenses,
  List<MajorCalendarEvent> calendarEvents = const [],
  WorkArrivalStats? workStats,
  WorkArrivalStats? previousWorkStats,
  double? monthlyBudgetBdt,
  String? monthlyIncomeBdt,
}) {
  final anomalies = <AnomalyCandidate>[];
  final nightsWithData = dailySleep.where((night) => night.hasData).toList();

  final clusters = detectSleepClusters(dailySleep);
  if (clusters.isNotEmpty) {
    final cluster = clusters.reduce(
      (a, b) => a.shortCount >= b.shortCount ? a : b,
    );
    final calendarOverlap = calendarEvents.any(
      (event) =>
          !event.end.isBefore(cluster.start) &&
          !event.start.isAfter(cluster.end),
    );
    final lateOverlap = workStats != null &&
        workStats.lateArrivals.any(
          (arrival) =>
              !arrival.date.isBefore(cluster.start) &&
              !arrival.date.isAfter(cluster.end),
        );
    final clusterSeverity = _clampScore(cluster.shortCount * 2);

    if (clusterSeverity > 0) {
      anomalies.add(
        AnomalyCandidate(
          label: cluster.rankingLabel,
          severity: clusterSeverity,
          recurrence: _clampScore(cluster.spanDays),
          crossDomain: calendarOverlap
              ? 8
              : lateOverlap
              ? 6
              : 4,
          priorityTier: 8,
        ),
      );
    }
  }

  if (nightsWithData.isNotEmpty) {
    final debt = computeSleepDebt(nightsWithData);
    if (debt.nightsBelowTarget >= 3) {
      final debtSeverity = _clampScore(debt.nightsBelowTarget);
      if (debtSeverity > 0) {
        anomalies.add(
          AnomalyCandidate(
            label: 'Sleep debt accumulation',
            severity: debtSeverity,
            recurrence: _clampScore(debt.nightsBelowTarget),
            crossDomain: workStats != null && workStats.lateArrivalCount > 0
                ? 7
                : 4,
            priorityTier: 1,
          ),
        );
      }
    }
  }

  if (workStats != null && workStats.lateArrivalCount > 0) {
    final lateRate = workStats.lateArrivalRate ?? 0;
    final previousLateRate = previousWorkStats?.lateArrivalRate;
    final rateWorsened = previousLateRate != null &&
        lateRate - previousLateRate >= attendanceLateRateWorseningThreshold;
    final sleepCorrelation = lateArrivalShortSleepCorrelationPercent(
      workStats: workStats,
      dailySleep: dailySleep,
    );
    var severity = _clampScore((lateRate / 10).round());
    var crossDomain = nightsWithData.isNotEmpty ? 6 : 3;
    if (rateWorsened &&
        sleepCorrelation > attendanceSleepCorrelationBoostThreshold) {
      severity = _clampScore(severity + 3);
      crossDomain = 8;
    }
    if (severity > 0) {
      anomalies.add(
        AnomalyCandidate(
          label: 'Attendance degradation',
          severity: severity,
          recurrence: _clampScore(workStats.lateArrivalCount),
          crossDomain: crossDomain,
          priorityTier: 2,
        ),
      );
    }
  }

  final expenseSummary = expenses;
  if (expenseSummary != null && expenseSummary.transactions.isNotEmpty) {
    final totalSpent = expenseSummary.totalRealExpenses;
    final incomeBaseline = _resolvedMonthlyIncome(
      expenseSummary,
      monthlyIncomeBdt,
    );

    final hasBudgetOverrun = monthlyBudgetBdt != null &&
        monthlyBudgetBdt > 0 &&
        totalSpent > monthlyBudgetBdt;
    if (hasBudgetOverrun) {
      final overrunShare = (totalSpent - monthlyBudgetBdt) / monthlyBudgetBdt;
      final overrunSeverity = _clampScore((overrunShare * 100 / 5).round());
      if (overrunSeverity > 0) {
        anomalies.add(
          AnomalyCandidate(
            label: 'Budget overrun',
            severity: overrunSeverity,
            recurrence: 4,
            crossDomain: 5,
            priorityTier: 3,
          ),
        );
      }
    }

    final topCategory = expenseSummary.expensesByCategory.first;
    final topSpendingShare =
        totalSpent > 0 ? topCategory.total / totalSpent : 0;
    final categoryIncomeShare = incomeBaseline > 0
        ? topCategory.total / incomeBaseline
        : null;
    final explainedByCalendar = categoryPurchasesExplainedByCalendar(
      expenses: expenseSummary,
      category: topCategory.category,
      calendarEvents: calendarEvents,
    );
    final hasCrossDomainImpact = topCategory.count >= 4;
    final belowIncomeCap = categoryIncomeShare != null &&
        categoryIncomeShare < spendingClusterIncomeShareSuppressThreshold;
    final suppressSpendingCluster = !hasBudgetOverrun &&
        belowIncomeCap &&
        explainedByCalendar;
    if (topSpendingShare >= spendingClusterMinSpendingShare &&
        !suppressSpendingCluster) {
      var severity = _clampScore((topSpendingShare * 100 / 5).round());
      var crossDomain = hasCrossDomainImpact ? 7 : 3;
      if (!hasBudgetOverrun &&
          belowIncomeCap &&
          explainedByCalendar &&
          !hasCrossDomainImpact) {
        severity = _clampScore(
          severity > spendingClusterReducedSeverityCap
              ? spendingClusterReducedSeverityCap
              : severity,
        );
        crossDomain = 2;
      }
      if (severity > 0) {
        anomalies.add(
          AnomalyCandidate(
            label: '${topCategory.category} spending cluster',
            severity: severity,
            recurrence: _clampScore(topCategory.count),
            crossDomain: crossDomain,
            priorityTier: 7,
          ),
        );
      }
    }

    final report = const ExpenseAnomalyFilter().analyze(expenseSummary);
    final purchaseAnomalies = report.anomalies
        .where((anomaly) => !ExpensesSummary.isFuelExpense(anomaly.transaction))
        .toList()
      ..sort(
        (a, b) => b.transaction.amount
            .abs()
            .compareTo(a.transaction.amount.abs()),
      );
    for (final anomaly in purchaseAnomalies.take(2)) {
      final amount = anomaly.transaction.amount.abs();
      final label = ExpensesSummary.subcategoryLabel(anomaly.transaction);
      final incomeShare = incomeBaseline > 0 ? amount / incomeBaseline : 0;
      final purchaseSeverity =
          _clampScore((incomeShare * 100 / 2.5).round());
      if (purchaseSeverity <= 0) continue;

      anomalies.add(
        AnomalyCandidate(
          label: '$label purchase',
          severity: purchaseSeverity,
          recurrence: 2,
          crossDomain: 5,
          priorityTier: 5,
        ),
      );
    }
  }

  final deduped = <String, AnomalyCandidate>{};
  for (final anomaly in anomalies) {
    final existing = deduped[anomaly.label.toLowerCase()];
    if (existing == null ||
        anomaly.impactScore > existing.impactScore ||
        (anomaly.impactScore == existing.impactScore &&
            anomaly.recurrence > existing.recurrence)) {
      deduped[anomaly.label.toLowerCase()] = anomaly;
    }
  }

  return rankAnomalyCandidates(
    _mergeCategoryAnomalies(deduped.values),
  );
}

String formatAnomalyCandidatesText(List<AnomalyCandidate> anomalies) {
  if (anomalies.isEmpty) {
    return '''
Severe cluster: none
No statistically significant anomalies detected.'''
        .trimRight();
  }

  final buffer = StringBuffer('Anomaly Candidates');
  for (final anomaly in anomalies) {
    buffer
      ..writeln()
      ..writeln()
      ..writeln(anomaly.label)
      ..writeln('- Severity: ${anomaly.severity}')
      ..writeln('- Recurrence: ${anomaly.recurrence}')
      ..writeln('- Cross-domain: ${anomaly.crossDomain}')
      ..writeln('- Impact score: ${anomaly.impactScore}');
  }

  return buffer.toString().trimRight();
}

int _clampScore(int value) {
  if (value < 0) return 0;
  if (value > 10) return 10;
  return value;
}

AnomalyCandidate? highestSeverityCandidate(List<AnomalyCandidate> candidates) {
  if (candidates.isEmpty) return null;
  final ranked = rankAnomalyCandidates(candidates);
  return ranked.isEmpty ? null : ranked.first;
}

double _resolvedMonthlyIncome(
  ExpensesSummary summary,
  String? monthlyIncomeBdt,
) {
  if (summary.totalIncome > 0) return summary.totalIncome;
  return parseMonthlyIncomeBdt(monthlyIncomeBdt ?? '') ?? 0;
}

bool categoryPurchasesExplainedByCalendar({
  required ExpensesSummary expenses,
  required String category,
  required List<MajorCalendarEvent> calendarEvents,
}) {
  if (calendarEvents.isEmpty) return false;

  final purchases = expenses.transactions
      .where(
        (tx) =>
            tx.isRealExpense &&
            ExpensesSummary.subcategoryLabel(tx) == category,
      )
      .toList();
  if (purchases.isEmpty) return false;

  return purchases.every(
    (tx) => findExpenseEventAssociation(
      transaction: tx,
      calendarEvents: calendarEvents,
    ).hasAssociation,
  );
}

double lateArrivalShortSleepCorrelationPercent({
  required WorkArrivalStats workStats,
  required List<DailySleepEntry> dailySleep,
}) {
  if (workStats.lateArrivals.isEmpty) return 0;

  final sleepByWakeDate = {
    for (final night in dailySleep.where((night) => night.hasData))
      _wakeDateKey(night.wakeDate): night,
  };

  var precededByShortSleep = 0;
  for (final arrival in workStats.lateArrivals) {
    final night = sleepByWakeDate[_wakeDateKey(arrival.date)];
    final isShort =
        night != null && night.session!.duration < sleepTargetDuration;
    if (isShort) precededByShortSleep++;
  }

  return precededByShortSleep / workStats.lateArrivals.length * 100;
}

String _wakeDateKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month}-${local.day}';
}

List<AnomalyCandidate> _mergeCategoryAnomalies(
  Iterable<AnomalyCandidate> candidates,
) {
  final byCategory = <String, AnomalyCandidate>{};
  final merged = <AnomalyCandidate>[];

  for (final candidate in candidates) {
    final categoryKey = _categoryAnomalyKey(candidate.label);
    if (categoryKey == null) {
      merged.add(candidate);
      continue;
    }
    final existing = byCategory[categoryKey];
    byCategory[categoryKey] = existing == null
        ? candidate
        : _preferCategoryAnomaly(existing, candidate);
  }

  return [...merged, ...byCategory.values];
}

String? _categoryAnomalyKey(String label) {
  const clusterSuffix = ' spending cluster';
  const purchaseSuffix = ' purchase';
  if (label.endsWith(clusterSuffix)) {
    return label
        .substring(0, label.length - clusterSuffix.length)
        .trim()
        .toLowerCase();
  }
  if (label.endsWith(purchaseSuffix)) {
    return label
        .substring(0, label.length - purchaseSuffix.length)
        .trim()
        .toLowerCase();
  }
  return null;
}

AnomalyCandidate _preferCategoryAnomaly(
  AnomalyCandidate existing,
  AnomalyCandidate candidate,
) {
  final existingCluster = existing.label.endsWith(' spending cluster');
  final candidateCluster = candidate.label.endsWith(' spending cluster');
  if (existingCluster && !candidateCluster) return existing;
  if (candidateCluster && !existingCluster) return candidate;
  return candidate.impactScore >= existing.impactScore
      ? candidate
      : existing;
}
