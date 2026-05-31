import 'package:intl/intl.dart';

import 'period_range.dart';

/// Analysis uses the current calendar month through today; the checklist targets next month.
class AnalysisPeriod {
  const AnalysisPeriod({
    required this.dataMonthStart,
    required this.dataMonthEnd,
    required this.checklistMonthStart,
  });

  final DateTime dataMonthStart;
  final DateTime dataMonthEnd;
  final DateTime checklistMonthStart;

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

  String get checklistMonthLabel =>
      DateFormat('MMMM yyyy').format(checklistMonthStart);

  factory AnalysisPeriod.forReference([DateTime? reference]) {
    final ref = (reference ?? DateTime.now()).toLocal();
    final dataRange = currentMonthToDateRange(ref);
    return AnalysisPeriod(
      dataMonthStart: dataRange.start,
      dataMonthEnd: dataRange.end,
      checklistMonthStart: DateTime(ref.year, ref.month + 1, 1),
    );
  }
}

bool isDateInRange(DateTime date, DateTime start, DateTime end) {
  final local = date.toLocal();
  return !local.isBefore(start) && !local.isAfter(end);
}
