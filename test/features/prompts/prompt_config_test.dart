import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/prompts/prompt_template_sections.dart';

void main() {
  test('composeTemplate includes locked sections and placeholders', () {
    final config = PromptConfig.initial();
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
    expect(composed, contains('Cross-Reference Domains'));
    expect(composed, contains('{{focus}}'));
    expect(composed, isNot(contains('{{avgSteps}}')));
    expect(composed, contains('weekly segments'));
    expect(composed, contains('entire month'));
    expect(composed, isNot(contains('{{checklistWeekCount}}')));
  });

  test('composeTemplate uses edited monthly income in rules', () {
    final config = PromptConfig.initial().copyWith(monthlyIncomeBdt: '42,000');
    final composed = config.composeTemplate();

    expect(composed, contains('42,000 BDT monthly income baseline'));
    expect(composed, isNot(contains('{{avgSteps}}')));
    expect(composed, isNot(contains('35,000 BDT monthly income baseline')));
  });

  test('composeSystemInstruction includes financial baseline from form', () {
    final config = PromptConfig.initial().copyWith(monthlyIncomeBdt: '50,000');
    final system = config.composeSystemInstruction();

    expect(system, contains('Monthly income is 50,000 BDT'));
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
