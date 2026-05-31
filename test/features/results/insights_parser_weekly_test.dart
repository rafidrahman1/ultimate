import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/results/insights_parser.dart';

void main() {
  test('parse groups actions under ##### week headers', () {
    const markdown = '''
### **Clear Next Actions (June 2026)**

##### **Week 1 · 1 Jun 2026 – 7 Jun 2026**
#### **1. Health & Sleep**
* **Sleep target:** In bed by 12:30 AM.

##### **Week 2 · 8 Jun 2026 – 14 Jun 2026**
#### **2. Expenses & Cashew App**
* **Spend cap:** Max 4,000 BDT this week.
''';

    final report = InsightParser.parse(markdown);

    expect(report.weeks, hasLength(2));
    expect(report.weeks[0].actions, hasLength(1));
    expect(report.weeks[1].actions, hasLength(1));
    expect(report.actions, hasLength(2));
    expect(report.weeks[0].weekNumber, 1);
  });
}
