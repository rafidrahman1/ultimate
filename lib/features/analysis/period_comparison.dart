import 'package:personal/features/analysis/analysis_period.dart';

extension AnalysisPeriodComparison on AnalysisPeriod {
  /// Same calendar-day span in the immediately preceding month.
  AnalysisPeriod get previousComparablePeriod {
    final prevStart = DateTime(
      dataMonthStart.year,
      dataMonthStart.month - 1,
      dataMonthStart.day,
    );
    final prevEndDay = DateTime(
      dataMonthEnd.year,
      dataMonthEnd.month - 1,
      dataMonthEnd.day,
    );
    final prevEnd = DateTime(
      prevEndDay.year,
      prevEndDay.month,
      prevEndDay.day,
      23,
      59,
      59,
      999,
      999,
    );
    return AnalysisPeriod(dataMonthStart: prevStart, dataMonthEnd: prevEnd);
  }
}
