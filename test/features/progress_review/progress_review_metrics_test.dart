import 'package:flutter_test/flutter_test.dart';
import 'package:Personal/features/progress_review/progress_review_metrics.dart';
import 'package:Personal/features/progress_review/progress_review_parser.dart';

void main() {
  test('extracts chart metrics from progress review sample', () {
    const sample = '''
### **Overall Improvement**
* **Checklist adherence:** 0 of 20 actions marked complete — 0%
* **Overall score:** **34/100** — spending stayed below cap.

### **Domain Progress**
#### **Health & Sleep**
* **Checklist target:** steps increasing from **3,705/day** to **5,705/day**.
* **Actual outcome:** Average steps were **532/day** across 30 days.
* **Verdict:** Declined
* **Score:** **8/100**

#### **Expenses**
* **Checklist target:** keep total June outlays at or below **15,000 BDT**.
* **Actual outcome:** Total real expenses were **3,813 BDT**.
* **Verdict:** Partial
* **Score:** **62/100**

#### **Location & Mobility**
* **Checklist target:** Cap motorcycle travel at **100 km**.
* **Actual outcome:** Motorcycle total distance was **86.75 km**.
* **Verdict:** Improved
* **Score:** **78/100**

### **What Worked**
* **Mobility restraint:** June motorcycle distance was held to **86.75 km**.

### **Gaps & Next Focus**
* **Steps gap:** Raise daily steps from **532/day** to at least **3,705/day**.
''';

    final report = ProgressReviewParser.parse(sample);
    final metrics = ProgressReviewMetrics.fromReport(report);

    expect(metrics.overallScore, 34);
    expect(metrics.adherenceCompleted, 0);
    expect(metrics.adherenceTotal, 20);
    expect(metrics.domainScores, hasLength(3));
    expect(metrics.comparisons, hasLength(3));
    expect(metrics.comparisons.first.label, 'Daily steps');
    expect(metrics.highlights.first.value, '86.75');
    expect(metrics.focusGaps.first.unit, 'steps/day');
  });
}
