import 'package:flutter_test/flutter_test.dart';
import 'package:personal/core/analysis_period.dart';
import 'package:personal/core/period_range.dart';

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
    expect(period.checklistWeeks.last.rangeLabel, '29 Jun 2026 – 30 Jun 2026');
    expect(
      period.checklistWeeksPromptBlock,
      contains('Weekly segments for June 2026 (5 weeks)'),
    );
  });

  test('currentMonthToDateRange ends on reference day', () {
    final range = currentMonthToDateRange(DateTime(2026, 5, 3, 9));
    expect(range.start, DateTime(2026, 5, 1));
    expect(range.end.day, 3);
  });

  test('calendarMonthRange covers full month', () {
    final range = calendarMonthRange(DateTime(2026, 2, 10));
    expect(range.start, DateTime(2026, 2, 1));
    expect(range.end.day, 28);
    expect(range.end.month, 2);
  });
}
