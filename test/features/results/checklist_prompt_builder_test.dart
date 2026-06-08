import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/results/checklist_prompt_builder.dart';
import 'package:personal/features/results/insights_models.dart';

void main() {
  test('buildChecklistTargetsPromptBlock includes completion marks', () {
    final period = AnalysisPeriod.forReference(DateTime(2026, 5, 28));
    final report = InsightsParsedReport(
      weeks: [
        InsightChecklistWeek(
          title: 'Week 1',
          weekNumber: 1,
          actions: [
            ActionDirective(
              title: 'Steps target',
              description: 'Walk 4,000 steps/day',
              category: 'Health',
              groupLabel: 'Health & Sleep',
            ),
            ActionDirective(
              title: 'Spend cap',
              description: 'Limit dining to 3,000 BDT',
              category: 'Expenses',
              groupLabel: 'Expenses & Cashew App',
            ),
          ],
        ),
      ],
      actions: [
        ActionDirective(
          title: 'Steps target',
          description: 'Walk 4,000 steps/day',
          category: 'Health',
        ),
        ActionDirective(
          title: 'Spend cap',
          description: 'Limit dining to 3,000 BDT',
          category: 'Expenses',
        ),
      ],
    );

    final block = buildChecklistTargetsPromptBlock(
      report: report,
      checklistPeriod: period,
      completionByWeek: {0: {0}},
      sourceResultTitle: 'Monthly insights · May 2026',
      sourceGeneratedAt: DateTime(2026, 5, 28, 12),
    );

    expect(block, contains('Monthly insights · May 2026'));
    expect(block, contains('June 2026'));
    expect(block, contains('[x] **Steps target**'));
    expect(block, contains('[ ] **Spend cap**'));
  });

  test('buildChecklistCompletionSummary counts marked actions', () {
    final report = InsightsParsedReport(
      weeks: [
        InsightChecklistWeek(
          title: 'Week 1',
          weekNumber: 1,
          actions: [
            ActionDirective(
              title: 'A',
              description: 'one',
              category: 'Health',
            ),
            ActionDirective(
              title: 'B',
              description: 'two',
              category: 'Health',
            ),
          ],
        ),
      ],
      actions: [
        ActionDirective(title: 'A', description: 'one', category: 'Health'),
        ActionDirective(title: 'B', description: 'two', category: 'Health'),
      ],
    );

    expect(
      buildChecklistCompletionSummary(
        report: report,
        completionByWeek: {0: {0}},
      ),
      '1 of 2 actions marked complete (50%)',
    );
  });
}
