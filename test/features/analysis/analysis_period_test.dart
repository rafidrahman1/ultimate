import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/analysis/analysis_period.dart';

void main() {
  test('current month runs month-to-date; checklist is next month', () {
    final period = AnalysisPeriod.forDataMonth(
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 18, 14),
    );

    expect(period.dataMonthStart, DateTime(2026, 9, 1));
    expect(period.dataMonthEnd.day, 18);
    expect(period.checklistMonthStart, DateTime(2026, 10, 1));
  });

  test('past month covers the whole calendar month', () {
    final period = AnalysisPeriod.forDataMonth(
      DateTime(2026, 2, 1),
      DateTime(2026, 9, 18),
    );

    expect(period.daysInDataMonth, 28);
    expect(period.checklistMonthStart, DateTime(2026, 3, 1));
  });

  test('December rolls the checklist into January', () {
    final period = AnalysisPeriod.forDataMonth(
      DateTime(2026, 12, 1),
      DateTime(2027, 1, 5),
    );
    expect(period.checklistMonthStart, DateTime(2027, 1, 1));
  });

  test('checklist weeks are 7-day slices with a short final week', () {
    final period = AnalysisPeriod.forDataMonth(
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 18),
    );
    final weeks = period.checklistWeeks; // October: 31 days

    expect(weeks, hasLength(5));
    expect(weeks.first.start, DateTime(2026, 10, 1));
    expect(weeks.first.end, DateTime(2026, 10, 7));
    expect(weeks.last.start, DateTime(2026, 10, 29));
    expect(weeks.last.end, DateTime(2026, 10, 31));
    expect(weeks.map((w) => w.weekNumber), [1, 2, 3, 4, 5]);
  });

  test('stored results recover the data month from their title', () {
    final period = AnalysisPeriod.forStoredResult(
      createdAt: DateTime(2026, 6, 2),
      title: 'Monthly insights · May 2026',
    );
    expect(period.dataMonthStart, DateTime(2026, 5, 1));
    expect(period.checklistMonthStart, DateTime(2026, 6, 1));
  });
}
