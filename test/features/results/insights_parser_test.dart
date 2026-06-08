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
* **Double Daily NEAT to 8,000 Steps:** Take 10-minute walking breaks every two hours.

#### **2. Expenses & Cashew App**
* **Execute Cashew App Reconciliation:** Survive the next 7 days on a strict budget cap of 4,000 BDT.

#### **3. Transport & Logistics**
* **Schedule Carburetor Tuning:** Book a mechanic this Friday.
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

#### **2. Expenses & Cashew App**
* **Cooling-Off & Spend Cap:** Enforce the active electronics cooling-off period.

#### **3. Location & Mobility**
* **Commute Cap:** Cap motorcycle travel at 100 km for the week.

#### **5. Calendar & Schedule**
* **Social Event Management:** On June 6, attend the Peshowarain Friends Meet.

##### **Week 2 · June 7 – June 13 · Theme: Stabilization**

#### **1. Health & Sleep**
* **Target Bedtime & Steps:** Shift bedtime window to 00:45–01:15.

#### **2. Expenses & Cashew App**
* **Discretionary Cap:** Maintain the electronics cooling-off period.

#### **3. Location & Mobility**
* **Fuel Refill:** Allow exactly one 500.00 BDT motorcycle fuel refill.

#### **5. Calendar & Schedule**
* **Routine Anchor:** Re-establish standard post-work evening walks.

##### **Week 3 · June 14 – June 20 · Theme: Improvement**

#### **1. Health & Sleep**
* **Target Bedtime & Steps:** Restrict bedtime to before 00:45.

#### **2. Expenses & Cashew App**
* **Cooling-Off Expiration:** The electronics cooling-off period expires on June 17.

#### **3. Location & Mobility**
* **Efficiency Audit:** Track weekly odometer readings in the Cashew App.

#### **5. Calendar & Schedule**
* **Holiday Adjustment:** Utilize the tentative Muharram public holiday on June 17.

##### **Week 4 · June 21 – June 27 · Theme: Maintenance**

#### **1. Health & Sleep**
* **Target Bedtime & Steps:** Stabilize bedtime at 00:30–00:45.

#### **2. Expenses & Cashew App**
* **Budget Tracking:** Limit discretionary spending to 1,500.00 BDT.

#### **3. Location & Mobility**
* **Fuel Refill:** Restrict fuel purchases to one 500.00 BDT refill.

#### **5. Calendar & Schedule**
* **Holiday Maintenance:** On the tentative Ashura public holiday on June 26.

##### **Week 5 · June 28 – June 30 · Theme: Review**

#### **1. Health & Sleep**
* **Target Bedtime & Steps:** Maintain the stabilized bedtime of 00:30–00:45.

#### **2. Expenses & Cashew App**
* **Monthly Financial Review:** Cap discretionary spending at 600.00 BDT.

#### **3. Location & Mobility**
* **Commute Audit:** Log final June odometer reading.

#### **5. Calendar & Schedule**
* **Next Month Baseline Planning:** Review Sunday-to-Thursday attendance consistency.
''';

void main() {
  test('InsightsReportParser.parse extracts anomalies and grouped actions', () {
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

  test('InsightsReportParser.parse returns empty report for blank input', () {
    final report = InsightsReportParser.parse('   ');
    expect(report.isEmpty, isTrue);
  });

  test('InsightsReportParser.parse maps May 2026 monthly insights export', () {
    final report = InsightsReportParser.parse(_may2026MonthlyInsights);

    expect(report.anomalies, hasLength(3));
    expect(report.anomalies[0].category, 'Health');
    expect(report.anomalies[1].category, 'Expenses');
    expect(report.anomalies[2].category, 'Transport');
    expect(report.weeks, hasLength(5));
    expect(report.weeks.first.theme, 'Recovery');
    expect(report.actions, hasLength(20));
    expect(
      report.actions.where((a) => a.category == 'Transport').length,
      5,
    );
    expect(report.themeForWeekIndex(4), 'Review');
    expect(report.actionsForWeekIndex(0), hasLength(4));
  });

  test('InsightsReportParser.parse skips Domain excluded checklist placeholders', () {
    const markdown = '''
### **Clear Next Actions (June 2026)**
##### **Week 1 · 2026-06-01 to 2026-06-07 · Theme: Recovery**
#### **4. Gaming & Leisure**
* Domain excluded.
#### **1. Health & Sleep**
* **Sleep target:** Bedtime before 01:00.
''';

    final report = InsightsReportParser.parse(markdown);

    expect(report.actions, hasLength(1));
    expect(report.actions.first.title, 'Sleep target');
  });

  test('InsightItemCategory.fromKeywords maps domains', () {
    expect(
      InsightItemCategory.fromKeywords('vespa fuel mileage').label,
      'Transport',
    );
    expect(
      InsightItemCategory.fromKeywords('location mobility motorcycle').label,
      'Transport',
    );
    expect(
      InsightItemCategory.fromKeywords('financial hemorrhage bdt').label,
      'Expenses',
    );
    expect(
      InsightItemCategory.fromKeywords('discretionary spending bdt').label,
      'Expenses',
    );
    expect(
      InsightItemCategory.fromKeywords('sleep cardiovascular').label,
      'Health',
    );
    expect(
      InsightItemCategory.fromGroupHeader('3. Location & Mobility').label,
      'Transport',
    );
  });
}
