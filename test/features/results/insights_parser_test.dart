import 'package:flutter_test/flutter_test.dart';
import 'package:Personal/features/results/insights_models.dart';
import 'package:Personal/features/results/insights_parser.dart';

const _sampleMarkdown = '''
### **Patterns & Anomalies**
* **Sleep Deprivation & Cardiovascular Stress:** Your average sleep of 5h 56m (bedtime 02:30, wake 08:33) leaves you chronically under-recovered.
* **Severe Financial Hemorrhage:** You have spent 29,337.55 BDT (83.82% of your 35,000 BDT salary) as of May 24.
* **Anemic NEAT vs. Aesthetic Goals:** Your daily step count of 4,017 is highly sedentary.
* **Abysmal Vespa Fuel Economy:** You tracked 175.8 km across 22 trips while spending 1,500 BDT on fuel.

### **Clear Next Actions (Next 7 Days)**
#### **1. Health & Sleep**
* **Enforce a 12:30 AM Sleep Lock:** Shift your bedtime back by two hours.
* **Double Daily NEAT to 8,000 Steps:** Take 10-minute walking breaks every two hours.

#### **2. Expenses & Cashew App**
* **Execute Cashew App Reconciliation:** Survive the next 7 days on a strict budget cap of 4,000 BDT.

#### **3. Transport & Logistics**
* **Schedule Carburetor Tuning:** Book a mechanic this Friday.
''';

void main() {
  test('InsightParser.parse extracts anomalies and grouped actions', () {
    final report = InsightParser.parse(_sampleMarkdown);

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

    expect(report.actions, hasLength(4));
    expect(
      report.actions.where((a) => a.category == 'Health').length,
      2,
    );
    expect(
      report.actions.where((a) => a.category == 'Expenses').length,
      1,
    );
    expect(
      report.actions.where((a) => a.category == 'Transport').length,
      1,
    );
    expect(
      report.actions.first.groupLabel,
      contains('Health'),
    );
  });

  test('InsightParser.parse returns empty report for blank input', () {
    final report = InsightParser.parse('   ');
    expect(report.isEmpty, isTrue);
  });

  test('InsightParser.parse skips Domain excluded checklist placeholders', () {
    const markdown = '''
### **Clear Next Actions (June 2026)**
##### **Week 1 · 2026-06-01 to 2026-06-07 · Theme: Recovery**
#### **4. Gaming & Leisure**
* Domain excluded.
#### **1. Health & Sleep**
* **Sleep target:** Bedtime before 01:00.
''';

    final report = InsightParser.parse(markdown);

    expect(report.actions, hasLength(1));
    expect(report.actions.first.title, 'Sleep target');
  });

  test('InsightItemCategory.fromKeywords maps domains', () {
    expect(
      InsightItemCategory.fromKeywords('vespa fuel mileage').label,
      'Transport',
    );
    expect(
      InsightItemCategory.fromKeywords('financial hemorrhage bdt').label,
      'Expenses',
    );
    expect(
      InsightItemCategory.fromKeywords('sleep cardiovascular').label,
      'Health',
    );
  });
}
