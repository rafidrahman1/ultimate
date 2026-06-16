import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/results/checklist_week_markdown.dart';

const _sampleOutput = '''
### **Patterns & Anomalies**
* **Sleep:** Average 6h.

### **Clear Next Actions (June 2026)**

##### **Week 1 · 2026-06-01 to 2026-06-07 · Theme: Recovery**

#### **Health & Sleep**
* **Bedtime:** Before 01:00.

#### **Calendar & Schedule**
* **Prep:** Light week before travel.

##### **Week 2 · 2026-06-08 to 2026-06-14 · Theme: Stabilization**

#### **Calendar & Schedule**
* **Family Visit:** Block recovery time after the visit.
''';

void main() {
  test('parseChecklistWeekSections extracts week blocks', () {
    final sections = parseChecklistWeekSections(_sampleOutput);

    expect(sections, hasLength(2));
    expect(sections[0].weekNumber, 1);
    expect(sections[1].weekNumber, 2);
    expect(sections[0].markdown, contains('Week 1'));
    expect(sections[1].markdown, contains('Family Visit'));
  });

  test('extractCalendarScheduleBlock returns calendar subsection text', () {
    final week = parseChecklistWeekSections(_sampleOutput).last.markdown;
    final block = extractCalendarScheduleBlock(week);

    expect(block, isNotNull);
    expect(block, contains('Family Visit'));
    expect(block, isNot(contains('#### **Health & Sleep**')));
  });

  test('calendarSectionMentionsEvent matches titles case-insensitively', () {
    expect(
      calendarSectionMentionsEvent(
        '* **Family Visit:** Block recovery time.',
        'family visit',
      ),
      isTrue,
    );
    expect(
      calendarSectionMentionsEvent(
        '* **Prep:** Light week.',
        'Dentist',
      ),
      isFalse,
    );
  });

  test('replaceChecklistWeekSection swaps one week block', () {
    final replacement = '''
##### **Week 1 · 2026-06-01 to 2026-06-07 · Theme: Recovery**

#### **Calendar & Schedule**
* **Dentist:** Confirm appointment on 5 Jun.
''';

    final updated = replaceChecklistWeekSection(_sampleOutput, 1, replacement);

    expect(updated, contains('Dentist'));
    expect(updated, contains('Family Visit'));
    expect(parseChecklistWeekSections(updated), hasLength(2));
  });
}
