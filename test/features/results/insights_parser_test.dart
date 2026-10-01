import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/results/insights_parser.dart';

const _report = '''
### **Patterns & Anomalies**

* **Sleep debt:** 9.5h below target across 12 nights. Likely linked to late gaming.
* **Fuel spend:** 3,200 BDT, up 18% vs last month.

### **Expense Category Ranking**

* **Food:** 8,000 BDT · 20.0% of income · 31 purchases

### **Clear Next Actions (October 2026)**

##### **Week 2 · 2026-10-08 to 2026-10-14 · Theme: Stabilization**

#### **Health & Sleep**

* **Lights out by 23:30:** At least 5 of 7 nights.

##### **Week 1 · 2026-10-01 to 2026-10-07 · Theme: Recovery**

#### **Health & Sleep**

* **Sleep 7h+:** At least 4 nights.

#### **Expenses**

* **Food cap:** Keep food under 1,800 BDT.
* **Domain excluded**
''';

void main() {
  test('parses anomalies from the patterns section only', () {
    final report = InsightsReportParser.parse(_report);

    expect(report.anomalies.map((a) => a.title), ['Sleep debt', 'Fuel spend']);
    expect(report.anomalies.first.description, startsWith('9.5h below'));
  });

  test('groups actions into weeks sorted by number, with themes', () {
    final report = InsightsReportParser.parse(_report);

    expect(report.weeks.map((w) => w.weekNumber), [1, 2]);
    expect(report.weeks.first.theme, 'Recovery');
    expect(report.weeks.first.actions.map((a) => a.title), [
      'Sleep 7h+',
      'Food cap',
    ]);
    expect(report.weeks.first.actions[1].groupLabel, 'Expenses');
    expect(report.actions, hasLength(3));
  });

  test('drops "Domain excluded" placeholder bullets', () {
    final report = InsightsReportParser.parse(_report);
    expect(
      report.actions.where((a) => a.title.toLowerCase().contains('excluded')),
      isEmpty,
    );
  });

  test('empty input parses to an empty report', () {
    final report = InsightsReportParser.parse('   ');
    expect(report.actions, isEmpty);
    expect(report.anomalies, isEmpty);
  });
}
