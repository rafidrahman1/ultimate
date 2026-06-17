import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/location/work_arrival_stats.dart';

/// Pre-report validation for analytics pipeline consistency.
class AnalyticsPipelineValidation {
  const AnalyticsPipelineValidation._();

  static const minEventAssociationConfidence = 0.5;

  static List<String> validateExpenseMetrics({
    required ExpensesSummary summary,
    required double monthlyIncome,
    double? monthlyBudget,
  }) {
    final warnings = <String>[];
    final totalSpent = summary.totalRealExpenses;
    final categories = summary.expensesByCategory;
    final categorySum = categories.fold<double>(0, (sum, stat) => sum + stat.total);

    if (categorySum > totalSpent + 0.01) {
      warnings.add(
        'Category totals ($categorySum) exceed total spending ($totalSpent).',
      );
    }

    if (categories.isNotEmpty && totalSpent > 0) {
      final top = categories.first;
      final topShare = top.total / totalSpent * 100;
      final second = categories.length > 1 ? categories[1].total : 0;
      if (second > top.total) {
        warnings.add(
          'Top category ranking mismatch: ${top.category} is listed first '
          'but is not the largest category.',
        );
      }
      if (topShare < 0 || topShare > 100) {
        warnings.add('Top category share ($topShare%) is out of range.');
      }
    }

    if (monthlyBudget != null && monthlyBudget > 0) {
      final consumed = totalSpent / monthlyBudget * 100;
      if (consumed.isNaN || consumed.isInfinite) {
        warnings.add('Budget consumed could not be calculated.');
      }
    }

    if (monthlyIncome > 0) {
      final incomeRemaining = monthlyIncome - totalSpent;
      if (incomeRemaining < -0.01 && totalSpent <= monthlyIncome) {
        warnings.add('Income remaining calculation is inconsistent.');
      }
    }

    return warnings;
  }

  static List<String> validateWorkAttendance(WorkArrivalStats workStats) {
    final warnings = <String>[];

    if (workStats.lateArrivalCount != workStats.lateArrivals.length) {
      warnings.add(
        'Late arrival count (${workStats.lateArrivalCount}) does not match '
        'detailed records (${workStats.lateArrivals.length}).',
      );
    }

    for (final arrival in workStats.lateArrivals) {
      if (!arrival.isLate) {
        warnings.add(
          'Non-late arrival on ${arrival.date} appears in late arrivals.',
        );
      }
      if (arrival.scheduledArrival != null &&
          !arrival.arrivalTime.isAfter(arrival.scheduledArrival!)) {
        warnings.add(
          'On-time or early arrival on ${arrival.date} appears in late arrivals.',
        );
      }
    }

    if (workStats.totalWorkDays > 0) {
      final expectedRate =
          workStats.lateArrivalCount / workStats.totalWorkDays * 100;
      final actualRate = workStats.lateArrivalRate;
      if (actualRate != null && (expectedRate - actualRate).abs() > 0.05) {
        warnings.add(
          'Late arrival rate ($actualRate%) does not match '
          'count/workdays ($expectedRate%).',
        );
      }
    }

    return warnings;
  }

  static List<String> validateEventAttributions({
    required List<CashewTransaction> transactions,
    required List<MajorCalendarEvent> calendarEvents,
  }) {
    final warnings = <String>[];
    for (final tx in transactions) {
      if (!tx.isRealExpense) continue;
      final association = findExpenseEventAssociation(
        transaction: tx,
        calendarEvents: calendarEvents,
      );
      if (association.hasAssociation &&
          association.confidence < minEventAssociationConfidence) {
        warnings.add(
          'Low-confidence event attribution for ${tx.date}: '
          '${association.eventName}.',
        );
      }
    }
    return warnings;
  }

  static void logWarnings(String context, List<String> warnings) {
    if (warnings.isEmpty) return;
    // ignore: avoid_print
    for (final warning in warnings) {
      print('Analytics validation [$context]: $warning');
    }
  }
}
