import 'package:intl/intl.dart';

import 'package:personal/core/period_range.dart';

/// Analysis uses the selected calendar month through today (or full month when past).
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
    );
  }

  /// Month-to-date through [reference].
  /// Used when rendering insights tied to a past analysis run timestamp.
  factory AnalysisPeriod.forReference([DateTime? reference]) {
    final ref = (reference ?? DateTime.now()).toLocal();
    final dataRange = currentMonthToDateRange(ref);
    return AnalysisPeriod(
      dataMonthStart: dataRange.start,
      dataMonthEnd: dataRange.end,
    );
  }

  /// Resolves the analyzed data month for a saved result.
  ///
  /// Prefer [dataMonthStart] when present. Otherwise parse the data month from
  /// [title] (e.g. "Monthly insights · May 2026"). Falls back to [forReference]
  /// for very old results.
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

bool isDateInRange(DateTime date, DateTime start, DateTime end) {
  final local = date.toLocal();
  return !local.isBefore(start) && !local.isAfter(end);
}
