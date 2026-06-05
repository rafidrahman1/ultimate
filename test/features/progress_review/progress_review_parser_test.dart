import 'package:flutter_test/flutter_test.dart';
import 'package:Personal/features/progress_review/progress_review_parser.dart';

void main() {
  test('parses progress review markdown structure', () {
    const sample = '''
### **Overall Improvement**

* **Checklist adherence:** 0 of 20 actions marked complete — 0%
* **Data-backed summary:** June performance was weak across the core measurable domains.
* **Overall score:** **34/100** — spending stayed below the hard monthly cap.

### **Domain Progress**

#### **Health & Sleep**

* **Checklist target:** Enforce bedtime windows from **01:00–01:30**.
* **Actual outcome:** Average steps were **532/day** across 30 days.
* **Verdict:** **Declined**
* **Score:** **8/100**
* **Delta:** Bedtime missed the earliest target by at least **1h 43m**.

#### **Expenses**

* **Checklist target:** Keep total June outlays at or below **15,000 BDT**.
* **Actual outcome:** Total real expenses were **3,813 BDT**.
* **Verdict:** **Partial**
* **Score:** **62/100**
* **Delta:** Monthly spending was **11,187 BDT under** the cap.

### **What Worked**

* **Mobility restraint:** June motorcycle distance was held to **86.75 km**.

### **Gaps & Next Focus**

* **Steps gap:** Raise daily steps from **532/day** to at least **3,705/day**.
''';

    final report = ProgressReviewParser.parse(sample);

    expect(report.checklistAdherence, contains('0 of 20'));
    expect(report.overallScore, contains('34/100'));
    expect(report.domains, hasLength(2));
    expect(report.domains.first.name, 'Health & Sleep');
    expect(report.domains.first.verdict, 'Declined');
    expect(report.domains.last.name, 'Expenses');
    expect(report.whatWorked, hasLength(1));
    expect(report.whatWorked.first.title, 'Mobility restraint');
    expect(report.gaps, hasLength(1));
    expect(report.gaps.first.title, 'Steps gap');
  });

  test('parses excluded domain as N/A without score', () {
    const sample = '''
### **Domain Progress**

#### **Gaming & Leisure**

* **Domain excluded.**
''';

    final report = ProgressReviewParser.parse(sample);

    expect(report.domains, hasLength(1));
    expect(report.domains.first.name, 'Gaming & Leisure');
    expect(report.domains.first.isExcluded, isTrue);
    expect(report.domains.first.score, 'N/A');
    expect(report.domains.first.verdict, 'N/A');
  });
}
