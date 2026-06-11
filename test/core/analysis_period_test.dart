import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/core/period_range.dart';

void main() {
  test('forReference uses current month to date', () {
    final period = AnalysisPeriod.forReference(DateTime(2026, 5, 15, 14));
    expect(period.dataMonthStart, DateTime(2026, 5, 1));
    expect(period.dataMonthEnd.day, 15);
    expect(period.dataMonthEnd.month, 5);
    expect(period.daysInDataMonth, 15);
    expect(period.dataRangeLabel, contains('May 2026'));
  });

  test('currentMonthToDateRange ends on reference day', () {
    final range = currentMonthToDateRange(DateTime(2026, 5, 3, 9));
    expect(range.start, DateTime(2026, 5, 1));
    expect(range.end.day, 3);
  });

  test('forDataMonth uses full calendar month for past months', () {
    final period = AnalysisPeriod.forDataMonth(
      DateTime(2026, 5, 15),
      DateTime(2026, 6, 7),
    );
    expect(period.dataMonthStart, DateTime(2026, 5, 1));
    expect(period.dataMonthEnd.day, 31);
    expect(period.dataMonthEnd.month, 5);
    expect(period.daysInDataMonth, 31);
  });

  test('forDataMonth uses month-to-date for the current month', () {
    final period = AnalysisPeriod.forDataMonth(
      DateTime(2026, 6, 1),
      DateTime(2026, 6, 7, 14),
    );
    expect(period.dataMonthStart, DateTime(2026, 6, 1));
    expect(period.dataMonthEnd.day, 7);
    expect(period.dataMonthEnd.month, 6);
    expect(period.daysInDataMonth, 7);
  });

  test('calendarMonthRange covers full month', () {
    final range = calendarMonthRange(DateTime(2026, 2, 10));
    expect(range.start, DateTime(2026, 2, 1));
    expect(range.end.day, 28);
    expect(range.end.month, 2);
  });

  test('forStoredResult uses saved data month instead of run date', () {
    final period = AnalysisPeriod.forStoredResult(
      createdAt: DateTime(2026, 6, 5),
      dataMonthStart: DateTime(2026, 5, 1),
    );
    expect(period.dataMonthStart, DateTime(2026, 5, 1));
    expect(period.dataMonthEnd.month, 5);
  });

  test('forStoredResult parses data month from legacy title', () {
    final period = AnalysisPeriod.forStoredResult(
      createdAt: DateTime(2026, 6, 5),
      title: 'Monthly insights · May 2026',
    );
    expect(period.dataMonthStart, DateTime(2026, 5, 1));
    expect(period.dataMonthEnd.month, 5);
  });
}
