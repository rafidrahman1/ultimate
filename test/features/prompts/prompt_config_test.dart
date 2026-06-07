import 'package:flutter_test/flutter_test.dart';
import 'package:Personal/core/analysis_period.dart';
import 'package:Personal/features/prompts/prompt_config_service.dart';

PromptConfig _samplePersonalConfig() {
  return PromptConfig.initial().copyWith(
    professionAndSchedule: 'Engineer, Mon–Fri 9–5',
    monthlyIncomeBdt: '80,000',
    financialInstruction: 'Strict budget optimization.',
    fitnessGoal: 'Maintain lean physique.',
    householdLifestyle: 'Lives with family.',
    decisionSupportRule: 'Provide Buy or Skip for electronics.',
  );
}

void main() {
  test('initial personal information fields are empty', () {
    final config = PromptConfig.initial();

    expect(config.professionAndSchedule, isEmpty);
    expect(config.monthlyIncomeBdt, isEmpty);
    expect(config.financialInstruction, isEmpty);
    expect(config.fitnessGoal, isEmpty);
    expect(config.householdLifestyle, isEmpty);
    expect(config.decisionSupportRule, isEmpty);
    expect(config.isPersonalInfoComplete, isFalse);
    expect(config.missingPersonalInfoLabels, hasLength(6));
  });

  test('isPersonalInfoComplete requires every personal field', () {
    final partial = PromptConfig.initial().copyWith(
      monthlyIncomeBdt: '50,000',
      fitnessGoal: 'Run a 5K',
    );

    expect(partial.isPersonalInfoComplete, isFalse);
    expect(partial.missingPersonalInfoLabels, isNot(contains('Monthly income (BDT)')));
    expect(partial.missingPersonalInfoLabels, contains('Profession and schedule'));
  });

  test('composeTemplate includes locked sections and placeholders', () {
    final config = _samplePersonalConfig();
    final composed = config.composeTemplate();

    expect(composed, contains('RULES FOR ANALYSIS:'));
    expect(composed, contains('DATA TO ANALYZE:'));
    expect(composed, contains('OUTPUT FORMAT:'));
    expect(composed, contains('{{health}}'));
    expect(composed, contains('{{location}}'));
    expect(composed, contains('{{gameActivity}}'));
    expect(composed, contains('{{calendar}}'));
    expect(composed, contains('{{focus}}'));
    expect(composed, contains(config.monthlyIncomeBdt));
    expect(composed, isNot(contains('{{monthlyIncomeBdt}}')));
    expect(composed, contains('Evidence Boundary (No Speculation)'));
    expect(composed, contains('{{focus}}'));
    expect(composed, contains('{{avgSteps}}'));
    expect(composed, contains('Week Blocks:'));
    expect(composed, contains('{{checklistWeekBlocks}}'));
    expect(composed, contains('entire month'));
    expect(composed, contains('top 3 anomalies first'));
    expect(composed, contains('{{checklistWeekCount}}'));
    expect(composed, contains('{{checklistWeekSegments}}'));
    expect(
      composed,
      isNot(contains('(week ranges filled at analysis run)')),
    );
  });

  test('composeTemplate uses edited monthly income in rules', () {
    final config = _samplePersonalConfig().copyWith(monthlyIncomeBdt: '42,000');
    final composed = config.composeTemplate();

    expect(composed, contains('Use 42,000 BDT as the monthly baseline.'));
    expect(composed, contains('{{avgSteps}}'));
    expect(composed, isNot(contains('Use 35,000 BDT as the financial baseline.')));
  });

  test('analysis run placeholder substitution fills week ranges and avg steps', () {
    final config = _samplePersonalConfig();
    final period = AnalysisPeriod.forDataMonth(DateTime(2026, 5, 1));
    final focus = config.focus.replaceAll(
      '{{checklistMonth}}',
      period.checklistMonthLabel,
    );

    final rendered = config
        .composeTemplate()
        .replaceAll('{{focus}}', focus)
        .replaceAll('{{analysisMonth}}', period.dataRangeLabel)
        .replaceAll('{{checklistMonth}}', period.checklistMonthLabel)
        .replaceAll(
          '{{checklistWeekCount}}',
          period.checklistWeekCount.toString(),
        )
        .replaceAll(
          '{{checklistWeekSegments}}',
          period.checklistWeeksPromptBlock,
        )
        .replaceAll(
          '{{checklistWeekBlocks}}',
          period.checklistWeekBlocksPromptBlock,
        )
        .replaceAll('{{avgSteps}}', '2705');

    expect(rendered, contains('2705 avg/day'));
    expect(rendered, contains('June 2026'));
    expect(rendered, contains('Week 1:'));
    expect(rendered, isNot(contains('{{checklistWeekCount}}')));
    expect(rendered, isNot(contains('(week ranges filled at analysis run)')));
    expect(rendered, isNot(contains('— weekly segments')));
  });

  test('composeSystemInstruction includes financial baseline from form', () {
    final config = _samplePersonalConfig().copyWith(monthlyIncomeBdt: '50,000');
    final system = config.composeSystemInstruction();

    expect(system, contains('Monthly income is 50,000 BDT'));
  });

  test('composeProgressTemplate includes progress review sections', () {
    final config = _samplePersonalConfig();
    final composed = config.composeProgressTemplate();

    expect(composed, contains('RULES FOR PROGRESS REVIEW:'));
    expect(composed, contains('DATA FOR PROGRESS REVIEW:'));
    expect(composed, contains('{{checklistTargets}}'));
    expect(composed, contains('{{checklistCompletionSummary}}'));
    expect(composed, contains('{{verifiedFinancialFacts}}'));
    expect(composed, contains('{{domainScoringRules}}'));
    expect(composed, contains('{{dynamicDomainOutputFormat}}'));
    expect(composed, contains('Overall Improvement'));
    expect(composed, isNot(contains('Clear Next Actions')));
  });

  test('composeSystemInstruction does not inject hardcoded personal defaults', () {
    final config = PromptConfig.initial();
    final system = config.composeSystemInstruction();

    expect(system, isNot(contains('Rafid Rahman')));
    expect(system, isNot(contains('Catch Bangladesh')));
    expect(system, contains('Profession & Schedule:'));
    expect(system, contains('Monthly income is  BDT'));
  });

  test('fromLegacyJson keeps identity and tone from legacy template', () {
    final legacy = PromptConfig.fromLegacyJson({
      'template': 'My custom intro.\n\nRULES FOR ANALYSIS:\n1. Rule one.',
      'focus': 'Weekly spend',
    });

    expect(legacy.assistantIdentity, 'My custom intro.');
    expect(legacy.focus, 'Weekly spend');
    expect(legacy.composeTemplate(), isNot(contains('1. Rule one.')));
    expect(legacy.composeTemplate(), contains('RULES FOR ANALYSIS:'));
  });
}
