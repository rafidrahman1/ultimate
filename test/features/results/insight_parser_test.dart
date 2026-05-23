import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/results/insight_parser.dart';

void main() {
  test('parseInsightOutput splits sections and bullets', () {
    const output = '''
Focus: Weekly habits

Highlights
- Steps are strong today.
- Spending is within range.

Next actions (7 days)
- Review budget on Sunday.
''';

    final sections = parseInsightOutput(output);
    expect(sections.length, greaterThanOrEqualTo(2));
    expect(sections.any((s) => s.title.toLowerCase().contains('highlight')), isTrue);
    expect(sections.any((s) => s.bullets.isNotEmpty), isTrue);
  });

  test('insightPreview returns first bullet', () {
    const output = '''
Highlights
- First insight line here.
- Second line.
''';
    expect(insightPreview(output), 'First insight line here.');
  });
}
