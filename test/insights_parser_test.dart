import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/results/reports/insights_parser.dart';

const _sample = '''
### **Patterns & Anomalies**

- **Late nights**: Sleep fell below 6h on five nights.
- **Fuel spike**: Fuel spending doubled in week 2.

### **Next Actions**

##### Week 1 (Theme: Sleep)

#### Health & Sleep

- **Lights out by 23:00**: Keep the phone out of the bedroom.

#### Expenses

- **Cap spending**: Keep outlays below 40,000 BDT this week.

##### Week 2: Hold the line

- **Walk daily**: 6,000 steps on working days.
''';

void main() {
  group('InsightsReportParser', () {
    test('empty input parses to an empty report', () {
      final report = InsightsReportParser.parse('   \n ');
      expect(report.isEmpty, isTrue);
      expect(report.checklistWeekCount, 0);
    });

    test('reads anomalies and weekly checklist actions', () {
      final report = InsightsReportParser.parse(_sample);
      expect(report.anomalies, hasLength(2));
      expect(report.anomalies.first.title, 'Late nights');
      expect(report.checklistWeekCount, 2);
      expect(report.actionsForWeekIndex(0), hasLength(2));
      expect(report.actionsForWeekIndex(1), hasLength(1));
      expect(report.actionsForWeekIndex(1).single.title, 'Walk daily');
    });

    test('week themes come from the week header', () {
      final report = InsightsReportParser.parse(_sample);
      expect(report.themeForWeekIndex(0), 'Sleep');
    });

    test('out-of-range week indexes are empty, not an error', () {
      final report = InsightsReportParser.parse(_sample);
      expect(report.actionsForWeekIndex(9), isEmpty);
      expect(report.actionsForWeekIndex(-1), isEmpty);
    });

    test('actions without week headers land in a single implicit week', () {
      final report = InsightsReportParser.parse('''
### Next Actions

- **Drink water**: Two litres a day.
''');
      expect(report.checklistWeekCount, 1);
      expect(report.actionsForWeekIndex(0).single.title, 'Drink water');
    });
  });
}
