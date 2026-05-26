import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/results/insight_models.dart';
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

  test('parseInsightReport handles markdown patterns and actions', () {
    const output = '''
Here is your personalized insights analysis based on your health, expense, and location data.

### **Patterns & Anomalies**

*   **The "Sedentary Commute" Loop:** Your daily steps are low (averaging **4,017 steps**), which directly correlates with **motorcycling** being your primary mode of transit (175.8 km across 22 trips). Your fuel expenses are highly predictable, occurring roughly every 4 to 8 days at a flat **500 BDT** per fill-up.
*   **Late-Night Sleep Deficit:** You are averaging only **5h 56m of sleep** per night. This is driven by a very late average bedtime of **2:30 AM**. 
*   **Frequent Food & Snack Outlays:** While your largest expenses were one-offs (15,410 BDT on gifts on May 8, and 6,000 BDT on electronics on May 18), you have a pattern of frequent micro-spending on "Snacks" and "Drinks" (occurring nearly every 1–2 days). This frequent snacking may also be linked to your late-night wake cycles.

---

### **Clear Next Actions (Next 7 Days)**

#### **1. Health & Sleep (Shift the Clock)**
*   **Pull bedtime back by 30 minutes:** Aim to be in bed by **2:00 AM** this week. This small shift will help push your sleep average past the 6.5-hour mark.
*   **Insert "Micro-Walks":** Because motorcycling limits your active transit, schedule two 10-minute walks immediately after lunch or dinner to boost your daily step average from 4,000 to **5,500 steps**.

#### **2. Expenses (Post-Spike Cool Down)**
*   **Initiate a "Snack-Free" Challenge:** Having spent heavily on gifts and electronics earlier in the month, target the next 7 days as a low-spend period. Try to limit "Snacks" and "Restaurant" purchases to a maximum of two occurrences this week. 
*   **Pre-plan your next Fuel stop:** Based on your May 5, 9, and 17 refueling pattern, your next 500 BDT fuel expense is likely due soon. Budget this in advance.

#### **3. Transport (Active Transit)**
*   **Substitute one ride:** Swap one short motorcycle trip this week for a walk or a Metro trip (similar to your May 19 trip) to naturally accumulate steps and break up the sedentary transit cycle.
''';

    final report = parseInsightReport(output);

    expect(report.patternsSection, isNotNull);
    expect(report.actionsSection, isNotNull);
    expect(report.allPatternBullets.length, 3);
    expect(report.allActions.length, greaterThanOrEqualTo(5));

    final sleep = report.sleepCard;
    expect(sleep, isNotNull);
    expect(sleep!.metric.toLowerCase(), contains('5h'));

    final finance = report.financeCard;
    expect(finance, isNotNull);
    expect(finance!.spikeAmount, contains('15,410'));

    final mobility = report.mobilityCard;
    expect(mobility, isNotNull);
    expect(mobility!.tripCount, '22');
  });
}
