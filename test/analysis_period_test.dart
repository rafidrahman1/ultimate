import 'package:flutter_test/flutter_test.dart';
import 'package:personal/core/period/analysis_period.dart';

void main() {
  group('AnalysisPeriod', () {
    test('forReference scopes data to month-to-date', () {
      final p = AnalysisPeriod.forReference(DateTime(2026, 3, 15));
      expect(p.dataMonthStart, DateTime(2026, 3, 1));
      expect(p.dataMonthEnd.day, 15);
    });

    test('a past data month is analysed in full', () {
      final p = AnalysisPeriod.forDataMonth(
        DateTime(2026, 1, 1),
        DateTime(2026, 3, 15),
      );
      expect(p.dataMonthEnd.day, 31);
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
