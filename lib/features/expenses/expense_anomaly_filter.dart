import 'package:personal/features/expenses/cashew_transaction.dart';

/// Share of monthly income for a purchase.
enum SpendingImpact {
  /// Below 3% of monthly income.
  minor,

  /// 3–10% of monthly income.
  moderate,

  /// Above 10% of monthly income.
  major,
}

extension SpendingImpactLabel on SpendingImpact {
  String get promptLabel => switch (this) {
        SpendingImpact.minor => 'minor spending impact',
        SpendingImpact.moderate => 'moderate spending impact',
        SpendingImpact.major => 'major spending impact',
      };
}

/// Flags unusually large purchases for AI analysis prompts.
class ExpenseAnomalyFilter {
  const ExpenseAnomalyFilter({
    this.minTransactionsForStats = 5,
    this.iqrMultiplier = 1.5,
    this.largePurchaseAbsolute = 1000,
    this.largePurchaseMedianMultiplier = 2.5,
    this.subcategoryMedianMultiplier = 2.0,
    this.subcategoryMinimumAmount = 400,
  });

  final int minTransactionsForStats;
  final double iqrMultiplier;
  final double largePurchaseAbsolute;
  final double largePurchaseMedianMultiplier;
  final double subcategoryMedianMultiplier;
  final double subcategoryMinimumAmount;

  static const double minorImpactMaxFraction = 0.03;
  static const double moderateImpactMaxFraction = 0.10;

  /// Classifies purchase size against [monthlyIncome].
  /// Returns null when income is zero or negative.
  static SpendingImpact? classifySpendingImpact({
    required double amount,
    required double monthlyIncome,
  }) {
    if (monthlyIncome <= 0) return null;
    final fraction = amount.abs() / monthlyIncome;
    if (fraction < minorImpactMaxFraction) return SpendingImpact.minor;
    if (fraction <= moderateImpactMaxFraction) return SpendingImpact.moderate;
    return SpendingImpact.major;
  }

  ExpenseAnomalyReport analyze(ExpensesSummary summary) {
    final expenses =
        summary.transactions.where((t) => t.isRealExpense).toList();
    if (expenses.isEmpty) {
      return const ExpenseAnomalyReport(anomalies: []);
    }

    final amounts = expenses.map((t) => t.amount.abs()).toList();
    final median = _median(amounts.map((a) => a.toDouble()).toList());
    final upperFence = _upperFence(amounts.map((a) => a.toDouble()).toList());
    final subcategoryMedians = _medianBySubcategory(expenses);
    final monthlyIncome = summary.totalIncome;

    final anomalies = <ExpenseAnomaly>[];
    for (final transaction in expenses) {
      final amount = transaction.amount.abs();
      final reasons = <String>[];

      if (amount >= largePurchaseAbsolute) {
        reasons.add('large purchase (≥${largePurchaseAbsolute.toStringAsFixed(0)})');
      }

      if (median > 0 && amount >= median * largePurchaseMedianMultiplier) {
        reasons.add(
          'well above usual spend (${amount.toStringAsFixed(0)} vs median '
          '${median.toStringAsFixed(0)})',
        );
      }

      if (upperFence != null &&
          expenses.length >= minTransactionsForStats &&
          amount > upperFence) {
        if (!reasons.any((r) => r.startsWith('well above usual'))) {
          reasons.add('statistical high outlier');
        }
      }

      final subLabel = ExpensesSummary.subcategoryLabel(transaction);
      final subMedian = subcategoryMedians[subLabel];
      if (subMedian != null &&
          amount >= subcategoryMinimumAmount &&
          amount >= subMedian * subcategoryMedianMultiplier) {
        reasons.add(
          'unusual for $subLabel (median ${subMedian.toStringAsFixed(0)})',
        );
      }

      if (reasons.isNotEmpty) {
        anomalies.add(
          ExpenseAnomaly(
            transaction: transaction,
            reasons: reasons,
            impact: classifySpendingImpact(
              amount: amount,
              monthlyIncome: monthlyIncome,
            ),
          ),
        );
      }
    }

    anomalies.sort((a, b) {
      final byDate = b.transaction.date.compareTo(a.transaction.date);
      if (byDate != 0) return byDate;
      return b.transaction.amount
          .abs()
          .compareTo(a.transaction.amount.abs());
    });

    return ExpenseAnomalyReport(anomalies: anomalies);
  }

  Map<String, double> _medianBySubcategory(List<CashewTransaction> expenses) {
    final bySub = <String, List<double>>{};
    for (final tx in expenses) {
      final label = ExpensesSummary.subcategoryLabel(tx);
      bySub.putIfAbsent(label, () => []).add(tx.amount.abs());
    }

    return bySub.map(
      (label, values) => MapEntry(label, _median(values)),
    );
  }

  double? _upperFence(List<double> values) {
    if (values.length < minTransactionsForStats) return null;
    final sorted = [...values]..sort();
    final q1 = _percentile(sorted, 0.25);
    final q3 = _percentile(sorted, 0.75);
    final iqr = q3 - q1;
    if (iqr <= 0) return null;
    return q3 + iqrMultiplier * iqr;
  }

  double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    return _percentile(sorted, 0.5);
  }

  double _percentile(List<double> sorted, double p) {
    assert(sorted.isNotEmpty);
    if (sorted.length == 1) return sorted.first;
    final index = p * (sorted.length - 1);
    final lower = index.floor();
    final upper = index.ceil();
    if (lower == upper) return sorted[lower];
    final weight = index - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }
}

class ExpenseAnomalyReport {
  const ExpenseAnomalyReport({required this.anomalies});

  final List<ExpenseAnomaly> anomalies;

  bool get hasAnomalies => anomalies.isNotEmpty;
}

class ExpenseAnomaly {
  const ExpenseAnomaly({
    required this.transaction,
    required this.reasons,
    this.impact,
  });

  final CashewTransaction transaction;
  final List<String> reasons;
  final SpendingImpact? impact;
}
