import 'package:flutter_test/flutter_test.dart';
import 'package:personal/core/analysis_period.dart';
import 'package:personal/features/results/insight_checklist_service.dart';

void main() {
  test('resolveDefaultChecklistWeekIndex picks week containing reference day', () {
    final period = AnalysisPeriod.forReference(DateTime(2026, 5, 28));
    expect(period.checklistMonthLabel, 'June 2026');
    final index = resolveDefaultChecklistWeekIndex(
      period: period,
      weekCount: period.checklistWeekCount,
      today: DateTime(2026, 6, 10),
    );
    expect(index, 1);
  });

  test('insightChecklistStorageKey scopes persistence per week', () {
    expect(insightChecklistStorageKey('abc', 2), 'abc_w2');
  });
}
