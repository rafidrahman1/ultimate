import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/results/insights_models.dart';
import 'package:personal/features/results/insights_parser.dart';

const _sampleMarkdown = '''
### **Patterns & Anomalies**
* **Sleep Deprivation & Cardiovascular Stress:** Your average sleep of 5h 56m (bedtime 02:30, wake 08:33) leaves you chronically under-recovered.
* **Severe Financial Hemorrhage:** You have spent 29,337.55 BDT (83.82% of your 35,000 BDT salary) as of May 24.
* **Anemic NEAT vs. Aesthetic Goals:** Your daily step count of 4,017 is highly sedentary.
* **Abysmal Vespa Fuel Economy:** You tracked 175.8 km across 22 trips while spending 1,500 BDT on fuel.

### **Clear Next Actions (Next 7 Days)**
#### **1. Health & Sleep**
* **Enforce a 12:30 AM Sleep Lock:** Shift your bedtime back by two hours.
''';

const _may2026MonthlyInsights = '''
### **Patterns & Anomalies**

* **Health & Sleep:** Average daily steps were 2,705, which is 9.8% below the critical 3,000-step daily baseline.
* **Discretionary Spending:** Total expenses reached 30,326.55 BDT, consuming 86.65% of the 35,000 BDT monthly income.
* **Location & Mobility:** Fuel expenses totaled 2,000.00 BDT across 4 refills (5.71% of monthly income).

### **Clear Next Actions (June 2026)**

##### **Week 1 · June 1 – June 6 · Theme: Recovery**

#### **1. Health & Sleep**
* **Target Bedtime & Steps:** Enforce a bedtime window of 01:00–01:30.
''';

void main() {
  test('InsightsReportParser.parse extracts anomalies only', () {
    final report = InsightsReportParser.parse(_sampleMarkdown);

    expect(report.anomalies, hasLength(4));
    expect(report.anomalies.first.title, contains('Sleep Deprivation'));
    expect(report.anomalies.first.category, 'Health');
    expect(
      report.anomalies.any((a) => a.category == 'Expenses'),
      isTrue,
    );
    expect(
      report.anomalies.any((a) => a.title.contains('Vespa')),
      isTrue,
    );
    expect(report.isEmpty, isFalse);
  });

  test('InsightsReportParser.parse returns empty report for blank input', () {
    final report = InsightsReportParser.parse('   ');
    expect(report.isEmpty, isTrue);
  });

  test('InsightsReportParser.parse maps May 2026 monthly insights anomalies', () {
    final report = InsightsReportParser.parse(_may2026MonthlyInsights);

    expect(report.anomalies, hasLength(3));
    expect(report.anomalies[0].category, 'Health');
    expect(report.anomalies[1].category, 'Expenses');
    expect(report.anomalies[2].category, 'Transport');
  });

  test('InsightsReportParser.parse ignores checklist sections', () {
    const markdown = '''
### **Clear Next Actions (June 2026)**
##### **Week 1 · 2026-06-01 to 2026-06-07 · Theme: Recovery**
#### **1. Health & Sleep**
* **Sleep target:** Bedtime before 01:00.
''';

    final report = InsightsReportParser.parse(markdown);

    expect(report.anomalies, isEmpty);
    expect(report.actions, isNotEmpty);
  });

  test('InsightItemCategory.fromGroupHeader maps gaming and calendar', () {
    expect(
      InsightItemCategory.fromGroupHeader('Gaming & Leisure').label,
      'Gaming',
    );
    expect(
      InsightItemCategory.fromGroupHeader('Calendar & Schedule').label,
      'Calendar',
    );
  });

  test('InsightsReportParser.parse maps gaming checklist actions', () {
    const markdown = '''
### **Clear Next Actions (July 2026)**

##### **Week 1 · 2026-07-01 to 2026-07-07 · Theme: Recovery**

#### **Gaming & Leisure**

* **Gaming cap:** Limit play to 90 minutes on weekdays.

#### **Calendar & Schedule**

* **Interview prep:** Block 30 minutes before the 31 Jul interview.
''';

    final report = InsightsReportParser.parse(markdown);

    expect(report.actions, hasLength(2));
    expect(report.actions[0].category, 'Gaming');
    expect(report.actions[0].groupLabel, 'Gaming & Leisure');
    expect(report.actions[1].category, 'Calendar');
    expect(report.actionCategories.map((c) => c.label), ['Gaming', 'Calendar']);
  });

  test('InsightItemCategory.fromKeywords maps domains', () {
    expect(
      InsightItemCategory.fromKeywords('vespa fuel mileage').label,
      'Transport',
    );
    expect(
      InsightItemCategory.fromKeywords('discretionary spending budget').label,
      'Expenses',
    );
    expect(
      InsightItemCategory.fromKeywords('sleep bedtime recovery').label,
      'Health',
    );
  });
}
