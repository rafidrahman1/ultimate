import 'package:flutter_test/flutter_test.dart';
import 'package:Personal/core/analysis_period.dart';
import 'package:Personal/core/period_range.dart';

void main() {
  test('forReference uses current month to date and next month for checklist',
      () {
    final period = AnalysisPeriod.forReference(DateTime(2026, 5, 15, 14));
    expect(period.dataMonthStart, DateTime(2026, 5, 1));
    expect(period.dataMonthEnd.day, 15);
    expect(period.dataMonthEnd.month, 5);
    expect(period.checklistMonthStart, DateTime(2026, 6, 1));
    expect(period.checklistMonthLabel, 'June 2026');
    expect(period.daysInDataMonth, 15);
    expect(period.checklistWeekCount, 5);
    expect(period.checklistWeeks.first.rangeLabel, '1 Jun 2026 – 7 Jun 2026');
    expect(period.checklistWeeks.first.isoRangeLabel, '2026-06-01 to 2026-06-07');
    expect(period.checklistWeeks.last.rangeLabel, '29 Jun 2026 – 30 Jun 2026');
    expect(period.checklistWeeks.last.isoRangeLabel, '2026-06-29 to 2026-06-30');
    expect(
      period.checklistWeeksPromptBlock,
      contains('Weekly segments for June 2026 (5 weeks)'),
    );
    expect(
      period.checklistWeeksPromptBlock,
      contains('Week 1: 2026-06-01 to 2026-06-07'),
    );
    expect(
      period.checklistWeekBlocksPromptBlock,
      '  - Week 1: 2026-06-01 to 2026-06-07\n'
      '  - Week 2: 2026-06-08 to 2026-06-14\n'
      '  - Week 3: 2026-06-15 to 2026-06-21\n'
      '  - Week 4: 2026-06-22 to 2026-06-28\n'
      '  - Week 5: 2026-06-29 to 2026-06-30',
    );
  });

  test('currentMonthToDateRange ends on reference day', () {
    final range = currentMonthToDateRange(DateTime(2026, 5, 3, 9));
    expect(range.start, DateTime(2026, 5, 1));
    expect(range.end.day, 3);
  });

  test('forDataMonth uses full calendar month and next checklist month', () {
    final period = AnalysisPeriod.forDataMonth(
      DateTime(2026, 5, 15),
      DateTime(2026, 6, 7),
    );
    expect(period.dataMonthStart, DateTime(2026, 5, 1));
    expect(period.dataMonthEnd.day, 31);
    expect(period.dataMonthEnd.month, 5);
    expect(period.checklistMonthStart, DateTime(2026, 6, 1));
    expect(period.checklistMonthLabel, 'June 2026');
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
    expect(period.checklistMonthStart, DateTime(2026, 7, 1));
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
    expect(period.checklistMonthLabel, 'June 2026');
  });

  test('forStoredResult parses data month from legacy title', () {
    final period = AnalysisPeriod.forStoredResult(
      createdAt: DateTime(2026, 6, 5),
      title: 'Monthly insights · May 2026',
    );
    expect(period.dataMonthStart, DateTime(2026, 5, 1));
    expect(period.checklistMonthLabel, 'June 2026');
  });
}
