import 'package:flutter_test/flutter_test.dart';
import 'package:personal/core/period/analysis_period.dart';

void main() {
  group('AnalysisPeriod', () {
    test(
      'forReference scopes data to month-to-date, checklist to next month',
      () {
        final p = AnalysisPeriod.forReference(DateTime(2026, 3, 15));
        expect(p.dataMonthStart, DateTime(2026, 3, 1));
        expect(p.dataMonthEnd.day, 15);
        expect(p.checklistMonthStart, DateTime(2026, 4, 1));
      },
    );

    test('December checklist rolls into January of the next year', () {
      final p = AnalysisPeriod.forReference(DateTime(2026, 12, 5));
      expect(p.checklistMonthStart, DateTime(2027, 1, 1));
    });

    test('checklist weeks are consecutive 7-day slices covering the month', () {
      final p = AnalysisPeriod.forReference(DateTime(2026, 1, 20));
      final weeks = p.checklistWeeks; // February 2026: 28 days
      expect(weeks, hasLength(4));
      expect(weeks.first.start, DateTime(2026, 2, 1));
      expect(weeks.last.end, DateTime(2026, 2, 28));
      for (var i = 1; i < weeks.length; i++) {
        expect(
          weeks[i].start.difference(weeks[i - 1].end).inDays,
          1,
          reason: 'week ${i + 1} must start the day after week $i',
        );
      }
    });

    test('a 31-day month ends in a short fifth week', () {
      final p = AnalysisPeriod.forReference(DateTime(2026, 4, 10)); // May
      final weeks = p.checklistWeeks;
      expect(weeks, hasLength(5));
      expect(weeks.last.start, DateTime(2026, 5, 29));
      expect(weeks.last.end, DateTime(2026, 5, 31));
    });

    test('a past data month is analysed in full', () {
      final p = AnalysisPeriod.forDataMonth(
        DateTime(2026, 1, 1),
        DateTime(2026, 3, 15),
      );
      expect(p.dataMonthEnd.day, 31);
      expect(p.checklistMonthStart, DateTime(2026, 2, 1));
    });

    test('stored result recovers its month from the title', () {
      final p = AnalysisPeriod.forStoredResult(
        createdAt: DateTime(2026, 9, 1),
        title: 'Monthly insights · May 2026',
      );
      expect(p.dataMonthStart, DateTime(2026, 5, 1));
    });
  });
}
