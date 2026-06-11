import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/results/analysis_checklist_builder.dart';

void main() {
  test('lists all selected domains in eligibility and sections', () {
    final selection = AnalysisSourceSelection.all();

    final eligibility = buildAnalysisChecklistDomainEligibilityBlock(selection);
    expect(eligibility, contains('Health & Sleep'));
    expect(eligibility, contains('Gaming & Leisure'));
    expect(eligibility, contains('Calendar & Schedule'));

    final sections = buildAnalysisChecklistDomainSectionsBlock(selection);
    expect(sections, contains('#### **Gaming & Leisure**'));
    expect(sections, contains('#### **Calendar & Schedule**'));
  });

  test('omits gaming when game activity is excluded', () {
    final selection = AnalysisSourceSelection({
      AnalysisDataSourceId.health,
      AnalysisDataSourceId.expenses,
      AnalysisDataSourceId.location,
      AnalysisDataSourceId.calendar,
    });

    final eligibility = buildAnalysisChecklistDomainEligibilityBlock(selection);
    expect(eligibility, isNot(contains('Gaming & Leisure')));

    final sections = buildAnalysisChecklistDomainSectionsBlock(selection);
    expect(sections, isNot(contains('Gaming & Leisure')));
    expect(sections, contains('#### **Calendar & Schedule**'));
  });
}
