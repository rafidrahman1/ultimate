import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_anomaly_filter.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_metrics.dart';
import 'package:personal/features/location/work_arrival_stats.dart';

class RankedAnomaly {
  const RankedAnomaly({
    required this.label,
    required this.severity,
    required this.recurrence,
    required this.crossDomain,
  });

  final String label;
  final int severity;
  final int recurrence;
  final int crossDomain;

  int get sortScore => severity * 100 + recurrence * 10 + crossDomain;
}

List<RankedAnomaly> buildAnomalyRanking({
  List<DailySleepEntry> dailySleep = const [],
  ExpensesSummary? expenses,
  List<MajorCalendarEvent> calendarEvents = const [],
  WorkArrivalStats? workStats,
}) {
  final anomalies = <RankedAnomaly>[];

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

    anomalies.add(
      RankedAnomaly(
        label: cluster.rankingLabel,
        severity: _clampScore(cluster.shortCount * 2),
        recurrence: _clampScore(cluster.spanDays),
        crossDomain: calendarOverlap
            ? 8
            : lateOverlap
            ? 6
            : 4,
      ),
    );
  }

  final expenseSummary = expenses;
  if (expenseSummary != null && expenseSummary.transactions.isNotEmpty) {
    final baseline = expenseSummary.totalIncome;
    final topCategory = expenseSummary.expensesByCategory.first;
    final topIncomeShare =
        baseline > 0 ? topCategory.total / baseline : 0;
    anomalies.add(
      RankedAnomaly(
        label: '${topCategory.category} spending',
        severity: _clampScore((topIncomeShare * 100 / 5).round()),
        recurrence: _clampScore(topCategory.count),
        crossDomain: topCategory.count >= 4 ? 7 : 5,
      ),
    );

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
      if (ExpensesSummary.isFuelExpense(anomaly.transaction)) continue;
      final amount = anomaly.transaction.amount.abs();
      final label = ExpensesSummary.subcategoryLabel(anomaly.transaction);
      final title = anomaly.transaction.title?.trim();
      final purchaseLabel = title != null && title.isNotEmpty
          ? '$label purchase'
          : '$label purchase';
      final incomeShare = baseline > 0 ? amount / baseline : 0;

      anomalies.add(
        RankedAnomaly(
          label: purchaseLabel,
          severity: _clampScore((incomeShare * 100 / 2.5).round()),
          recurrence: 2,
          crossDomain: 5,
        ),
      );
    }
  }

  final deduped = <String, RankedAnomaly>{};
  for (final anomaly in anomalies) {
    final existing = deduped[anomaly.label.toLowerCase()];
    if (existing == null || anomaly.sortScore > existing.sortScore) {
      deduped[anomaly.label.toLowerCase()] = anomaly;
    }
  }

  final ranked = deduped.values.toList()
    ..sort((a, b) {
      final scoreCompare = b.sortScore.compareTo(a.sortScore);
      if (scoreCompare != 0) return scoreCompare;
      return a.label.compareTo(b.label);
    });

  return ranked.take(5).toList();
}

String formatAnomalyRankingText(List<RankedAnomaly> anomalies) {
  if (anomalies.isEmpty) return '';

  final buffer = StringBuffer('Anomaly Ranking');
  for (var i = 0; i < anomalies.length; i++) {
    final anomaly = anomalies[i];
    buffer
      ..writeln()
      ..writeln()
      ..writeln('${i + 1}. ${anomaly.label}')
      ..writeln('Severity: ${anomaly.severity}')
      ..writeln('Recurrence: ${anomaly.recurrence}')
      ..writeln('Cross-domain: ${anomaly.crossDomain}');
  }

  return buffer.toString().trimRight();
}

int _clampScore(int value) {
  if (value < 0) return 0;
  if (value > 10) return 10;
  return value;
}
