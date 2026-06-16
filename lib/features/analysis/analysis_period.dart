import 'package:intl/intl.dart';

import 'package:personal/core/period_range.dart';

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

  /// Consecutive 7-day slices covering the full checklist month (last week may be shorter).
  List<ChecklistWeekSegment> get checklistWeeks {
    final year = checklistMonthStart.year;
    final month = checklistMonthStart.month;
    final lastDay = DateTime(year, month + 1, 0).day;

    final weeks = <ChecklistWeekSegment>[];
    var day = 1;
    var weekNumber = 1;
    while (day <= lastDay) {
      final start = DateTime(year, month, day);
      final endDay = day + 6 > lastDay ? lastDay : day + 6;
      final end = DateTime(year, month, endDay);
      weeks.add(
        ChecklistWeekSegment(weekNumber: weekNumber, start: start, end: end),
      );
      day = endDay + 1;
      weekNumber++;
    }
    return weeks;
  }

  int get checklistWeekCount => checklistWeeks.length;

  /// Week boundaries injected into the analysis prompt output format.
  String get checklistWeeksPromptBlock {
    final buffer = StringBuffer(
      'Weekly segments for $checklistMonthLabel ($checklistWeekCount weeks):\n',
    );
    for (final week in checklistWeeks) {
      buffer.writeln('- Week ${week.weekNumber}: ${week.isoRangeLabel}');
    }
    return buffer.toString().trimRight();
  }

  /// Week blocks appended to DATA TO ANALYZE (calendar section).
  String get checklistWeekBlocksPromptBlock {
    final buffer = StringBuffer();
    for (final week in checklistWeeks) {
      buffer.writeln('  - Week ${week.weekNumber}: ${week.isoRangeLabel}');
    }
    return buffer.toString().trimRight();
  }

  /// Selected calendar month for data; checklist targets the month after.
  ///
  /// Uses month-to-date when [monthStart] is the current month (same as
  /// [forReference]); otherwise the full calendar month.
  factory AnalysisPeriod.forDataMonth(
    DateTime monthStart, [
    DateTime? reference,
  ]) {
    final local = monthStart.toLocal();
    final anchor = DateTime(local.year, local.month, 1);
    final ref = (reference ?? DateTime.now()).toLocal();
    final isCurrentMonth =
        anchor.year == ref.year && anchor.month == ref.month;
    final dataRange = isCurrentMonth
        ? currentMonthToDateRange(ref)
        : calendarMonthRange(anchor);
    return AnalysisPeriod(
      dataMonthStart: dataRange.start,
      dataMonthEnd: dataRange.end,
      checklistMonthStart: DateTime(anchor.year, anchor.month + 1, 1),
    );
  }

  /// Month-to-date through [reference] and checklist for the following month.
  /// Used when rendering insights tied to a past analysis run timestamp.
  factory AnalysisPeriod.forReference([DateTime? reference]) {
    final ref = (reference ?? DateTime.now()).toLocal();
    final dataRange = currentMonthToDateRange(ref);
    return AnalysisPeriod(
      dataMonthStart: dataRange.start,
      dataMonthEnd: dataRange.end,
      checklistMonthStart: DateTime(ref.year, ref.month + 1, 1),
    );
  }

  /// Resolves the analyzed data month and checklist month for a saved result.
  ///
  /// Prefer [dataMonthStart] when present. Otherwise parse the data month from
  /// [title] (e.g. "Monthly insights · May 2026"). Falls back to [forReference]
  /// for very old results.
  /// Data window scoped to a single checklist week for weekly verification.
  factory AnalysisPeriod.forWeekVerification({
    required ChecklistWeekSegment week,
    required DateTime checklistMonthStart,
  }) {
    final start = DateTime(
      week.start.year,
      week.start.month,
      week.start.day,
    );
    final end = DateTime(week.end.year, week.end.month, week.end.day);
    return AnalysisPeriod(
      dataMonthStart: start,
      dataMonthEnd: end,
      checklistMonthStart: checklistMonthStart,
    );
  }

  factory AnalysisPeriod.forStoredResult({
    required DateTime createdAt,
    DateTime? dataMonthStart,
    String? title,
  }) {
    final resolvedStart =
        dataMonthStart ?? _parseDataMonthStartFromTitle(title);
    if (resolvedStart != null) {
      return AnalysisPeriod.forDataMonth(resolvedStart);
    }
    return AnalysisPeriod.forReference(createdAt);
  }

  static DateTime? _parseDataMonthStartFromTitle(String? title) {
    if (title == null || title.isEmpty) return null;
    final segments = title.split('·');
    if (segments.length < 2) return null;
    final monthLabel = segments.last.trim();
    if (monthLabel.isEmpty) return null;
    try {
      final parsed = DateFormat('MMMM yyyy').parseLoose(monthLabel);
      return DateTime(parsed.year, parsed.month, 1);
    } catch (_) {
      return null;
    }
  }
}

class ChecklistWeekSegment {
  const ChecklistWeekSegment({
    required this.weekNumber,
    required this.start,
    required this.end,
  });

  final int weekNumber;
  final DateTime start;
  final DateTime end;

  String get rangeLabel => formatPeriodRange(start, end);

  /// ISO date range for checklist week blocks in the analysis prompt data section.
  String get isoRangeLabel {
    final iso = DateFormat('yyyy-MM-dd');
    return '${iso.format(start.toLocal())} to ${iso.format(end.toLocal())}';
  }
}

bool isDateInRange(DateTime date, DateTime start, DateTime end) {
  final local = date.toLocal();
  return !local.isBefore(start) && !local.isAfter(end);
}
