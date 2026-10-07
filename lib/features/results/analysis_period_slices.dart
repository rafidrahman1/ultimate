part of 'analysis_service.dart';

MonthlyHealthSummary _sliceHealthForPeriod(
  MonthlyHealthSummary summary,
  AnalysisPeriod period,
) {
  final start = DateTime(
    period.dataMonthStart.year,
    period.dataMonthStart.month,
    period.dataMonthStart.day,
  );
  final end = DateTime(
    period.dataMonthEnd.year,
    period.dataMonthEnd.month,
    period.dataMonthEnd.day,
  );

  final filtered = summary.dailySleep.where((entry) {
    final day = DateTime(
      entry.wakeDate.year,
      entry.wakeDate.month,
      entry.wakeDate.day,
    );
    return !day.isBefore(start) && !day.isAfter(end);
  }).toList();

  return MonthlyHealthSummary(
    periodStart: period.dataMonthStart,
    periodEnd: period.dataMonthEnd,
    dailySleep: filtered,
    dayCount: period.daysInDataMonth,
  );
}
