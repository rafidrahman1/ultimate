import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/progress_review/progress_review_evaluation.dart';
import 'package:personal/features/progress_review/progress_review_metrics.dart';
import 'package:personal/features/progress_review/progress_review_parser.dart';
import 'package:personal/features/results/insights_models.dart';

void main() {
  group('VerifiedFinancialRatios', () {
    test('computes 10.9% spend and 32.0% headroom under 42.9% cap', () {
      const ratios = VerifiedFinancialRatios(
        actualExpensesBdt: 3813,
        monthlyBaselineBdt: 35000,
        spendingCapBdt: 15000,
      );

      expect(ratios.actualPercentOfIncome, closeTo(10.9, 0.05));
      expect(ratios.capPercentOfIncome, closeTo(42.9, 0.05));
      expect(ratios.headroomPercentUnderCap, closeTo(32.0, 0.05));

      final delta = ratios.buildExpenseDeltaLine();
      expect(delta, contains('10.9% of monthly income'));
      expect(delta, contains('32.0%'));
      expect(delta, contains('42.9% cap minus 10.9% actual'));
      expect(delta, isNot(contains('25.9%')));
    });
  });

  group('ProgressReviewEvaluationEngine', () {
    InsightsParsedReport sampleChecklist() {
      return InsightsParsedReport(
        weeks: [
          InsightChecklistWeek(
            title: 'Week 1',
            weekNumber: 1,
            actions: [
              ActionDirective(
                title: 'Spend cap',
                description: 'Keep total June outlays at or below 15,000 BDT',
                category: 'Expenses',
                groupLabel: 'Expenses & Cashew App',
              ),
              ActionDirective(
                title: 'Steps',
                description: 'Walk 3,705 steps/day',
                category: 'Health',
                groupLabel: 'Health & Sleep',
              ),
            ],
          ),
        ],
        actions: [
          ActionDirective(
            title: 'Spend cap',
            description: 'Keep total June outlays at or below 15,000 BDT',
            category: 'Expenses',
            groupLabel: 'Expenses & Cashew App',
          ),
          ActionDirective(
            title: 'Steps',
            description: 'Walk 3,705 steps/day',
            category: 'Health',
            groupLabel: 'Health & Sleep',
          ),
        ],
      );
    }

    test('marks gaming excluded when data omitted from run', () {
      final context = ProgressReviewEvaluationEngine.buildContext(
        checklist: sampleChecklist(),
        dataSnapshot: {
          'health': 'steps data',
          'expenses': 'expense data',
          'location': 'location data',
          'gameActivity': kProgressReviewExcludedDataMessage,
          'calendar': 'calendar data',
        },
        selection: AnalysisSourceSelection({
          AnalysisDataSourceId.health,
          AnalysisDataSourceId.expenses,
          AnalysisDataSourceId.location,
          AnalysisDataSourceId.calendar,
        }),
        monthlyIncomeBdt: '35,000',
        totalRealExpenses: 3813,
      );

      final gaming = context.domainEligibility
          .firstWhere((d) => d.id == ProgressReviewDomainId.gaming);
      expect(gaming.isScorable, isFalse);
      expect(gaming.checklistTargetCount, 0);
      expect(gaming.dataExcluded, isTrue);
    });

    test('enforce replaces hallucinated income percent and gaming score', () {
      const hallucinated = '''
### **Domain Progress**

#### **Expenses**

* **Checklist target:** keep total June outlays at or below **15,000 BDT**.
* **Actual outcome:** Total real expenses were **3,813 BDT**.
* **Verdict:** Partial
* **Score:** **62/100**
* **Delta:** Actual spend was **25.9% of monthly income**.

#### **Gaming & Leisure**

* **Checklist target:** Limit gaming to 10h/week.
* **Actual outcome:** Excluded from this analysis run.
* **Verdict:** Declined
* **Score:** **35/100**
* **Delta:** Insufficient data to verify.
''';

      final context = ProgressReviewEvaluationEngine.buildContext(
        checklist: sampleChecklist(),
        dataSnapshot: {
          'health': 'steps',
          'expenses': 'expenses',
          'location': 'location',
          'gameActivity': kProgressReviewExcludedDataMessage,
          'calendar': 'calendar',
        },
        selection: AnalysisSourceSelection({
          AnalysisDataSourceId.health,
          AnalysisDataSourceId.expenses,
          AnalysisDataSourceId.location,
          AnalysisDataSourceId.calendar,
        }),
        monthlyIncomeBdt: '35,000',
        totalRealExpenses: 3813,
      );

      final enforced =
          ProgressReviewEvaluationEngine.enforce(hallucinated, context);

      expect(enforced, contains('10.9% of monthly income'));
      expect(enforced, isNot(contains('25.9% of monthly income')));
      expect(enforced, contains('#### **Gaming & Leisure**'));
      expect(enforced, contains(kProgressReviewDomainExcludedBullet));
      expect(enforced, isNot(contains('**Score:** **35/100**')));

      final report = ProgressReviewParser.parse(enforced);
      final gaming = report.domains
          .firstWhere((d) => d.name.contains('Gaming'));
      expect(gaming.isExcluded, isTrue);
      expect(gaming.score, 'N/A');

      final metrics = ProgressReviewMetrics.fromReport(report);
      expect(
        metrics.domainScores.any((d) => d.name.contains('Gaming')),
        isFalse,
      );
    });

    test('parseEnforced applies eligibility to parsed domains', () {
      const raw = '''
#### **Gaming & Leisure**

* **Domain excluded.**
''';

      final context = ProgressReviewEvaluationEngine.buildContext(
        checklist: const InsightsParsedReport(),
        dataSnapshot: {
          'health': kProgressReviewExcludedDataMessage,
          'expenses': kProgressReviewExcludedDataMessage,
          'location': kProgressReviewExcludedDataMessage,
          'gameActivity': kProgressReviewExcludedDataMessage,
          'calendar': kProgressReviewExcludedDataMessage,
        },
        selection: const AnalysisSourceSelection({}),
        monthlyIncomeBdt: '35,000',
      );

      final report = ProgressReviewEvaluationEngine.parseEnforced(raw, context);
      expect(report.domains.first.isExcluded, isTrue);
      expect(report.domains.first.score, 'N/A');
    });
  });
}
