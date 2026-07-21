import 'package:personal/core/period_range.dart';

/// Data window: current calendar month through today, or a full past month.
class AnalysisPeriod {
  const AnalysisPeriod({
    required this.dataMonthStart,
    required this.dataMonthEnd,
  });

  final DateTime dataMonthStart;
  final DateTime dataMonthEnd;

  int get daysInDataMonth {
    final start = DateTime(
      dataMonthStart.year,
      dataMonthStart.month,
      dataMonthStart.day,
    );
    final end = DateTime(
      dataMonthEnd.year,
      dataMonthEnd.month,
      dataMonthEnd.day,
    );
    return end.difference(start).inDays + 1;
  }

  String get dataRangeLabel => formatPeriodRange(dataMonthStart, dataMonthEnd);

  /// Selected calendar month for data; month-to-date when it's the current month.
  factory AnalysisPeriod.forDataMonth(
    DateTime monthStart, [
    DateTime? reference,
  ]) {
    final local = monthStart.toLocal();
    final anchor = DateTime(local.year, local.month, 1);
    final ref = (reference ?? DateTime.now()).toLocal();
    final isCurrentMonth = anchor.year == ref.year && anchor.month == ref.month;
    final dataRange = isCurrentMonth
        ? currentMonthToDateRange(ref)
        : calendarMonthRange(anchor);
    return AnalysisPeriod(
      dataMonthStart: dataRange.start,
      dataMonthEnd: dataRange.end,
    );
  }

  /// Month-to-date through [reference].
  factory AnalysisPeriod.forReference([DateTime? reference]) {
    final ref = (reference ?? DateTime.now()).toLocal();
    final dataRange = currentMonthToDateRange(ref);
    return AnalysisPeriod(
      dataMonthStart: dataRange.start,
      dataMonthEnd: dataRange.end,
    );
  }
}

bool isDateInRange(DateTime date, DateTime start, DateTime end) {
  final local = date.toLocal();
  return !local.isBefore(start) && !local.isAfter(end);
}
