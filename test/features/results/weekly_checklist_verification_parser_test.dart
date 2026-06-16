import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/results/insights_models.dart';
import 'package:personal/features/results/weekly_checklist_verification_parser.dart';

void main() {
  const actions = [
    ActionDirective(
      title: 'Sleep Lock',
      description: 'Bed before 01:00',
      category: 'Health',
    ),
    ActionDirective(
      title: 'Spend Cap',
      description: 'Stay under 8000 BDT',
      category: 'Expenses',
    ),
  ];

  test('parses numbered Met and Failed verdicts', () {
    const markdown = '''
### **Weekly Checklist Verification**

##### Week 1 · June 1 – June 6

1. **Sleep Lock** — **Verdict:** Met
   - **Evidence:** Average bedtime 00:45
   - **Rationale:** Target met.

2. **Spend Cap** — **Verdict:** Failed
   - **Evidence:** 9200 BDT spent
   - **Rationale:** Over cap.
''';

    final result = WeeklyChecklistVerificationParser.parse(
      markdown,
      actions: actions,
    );

    expect(result.completedIndices, {0});
    expect(result.failedIndices, {1});
    expect(result.unverifiedIndices, isEmpty);
  });

  test('parses Unverified verdict', () {
    const markdown = '''
1. **Sleep Lock** — **Verdict:** Unverified
''';

    final result = WeeklyChecklistVerificationParser.parse(
      markdown,
      actions: actions,
    );

    expect(result.unverifiedIndices, {0});
    expect(result.completedIndices, isEmpty);
    expect(result.failedIndices, isEmpty);
  });

  test('matches by title when index missing', () {
    const markdown = '''
**Spend Cap** — **Verdict:** Failed
''';

    final result = WeeklyChecklistVerificationParser.parse(
      markdown,
      actions: actions,
    );

    expect(result.failedIndices, {1});
  });

  test('returns empty for blank input', () {
    final result = WeeklyChecklistVerificationParser.parse(
      '   ',
      actions: actions,
    );
    expect(result.items, isEmpty);
  });
}
