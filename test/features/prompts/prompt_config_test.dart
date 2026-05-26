import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/prompts/prompt_template_sections.dart';

void main() {
  test('composeTemplate includes locked sections and placeholders', () {
    final config = PromptConfig.initial();
    final composed = config.composeTemplate();

    expect(composed, contains(PromptTemplateSections.rulesForAnalysis));
    expect(composed, contains('DATA TO ANALYZE:'));
    expect(composed, contains('OUTPUT FORMAT:'));
    expect(composed, contains('{{health}}'));
    expect(composed, contains('{{location}}'));
    expect(composed, contains('{{focus}}'));
    expect(composed, contains(config.preamble));
  });

  test('fromLegacyJson keeps only preamble before rules marker', () {
    final legacy = PromptConfig.fromLegacyJson({
      'template': 'My custom intro.\n\nRULES FOR ANALYSIS:\n1. Rule one.',
      'focus': 'Weekly spend',
    });

    expect(legacy.preamble, 'My custom intro.');
    expect(legacy.focus, 'Weekly spend');
    expect(legacy.composeTemplate(), isNot(contains('1. Rule one.')));
    expect(
      legacy.composeTemplate(),
      contains(PromptTemplateSections.rulesForAnalysis),
    );
  });
}
