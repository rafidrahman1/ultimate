import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/results/report_format_repair.dart';

String _reportWithWeeks(int count) {
  final buffer = StringBuffer('### **Clear Next Actions (February 2026)**\n\n');
  for (var week = 1; week <= count; week++) {
    buffer
      ..writeln('##### **Week $week · range · Theme: Recovery**')
      ..writeln('#### **Health & Sleep**')
      ..writeln('* **Sleep 7h+:** At least 4 nights.')
      ..writeln();
  }
  return buffer.toString();
}

void main() {
  // January data month -> February checklist: 28 days = 4 weeks.
  final period = AnalysisPeriod.forDataMonth(
    DateTime(2026, 1, 1),
    DateTime(2026, 3, 10),
  );

  test('well-formed report has no problem', () {
    expect(period.checklistWeekCount, 4);
    expect(monthlyReportFormatProblem(_reportWithWeeks(4), period), isNull);
  });

  test('missing checklist is reported', () {
    expect(
      monthlyReportFormatProblem(
        'Here are some thoughts about your month.',
        period,
      ),
      contains('no checklist actions'),
    );
  });

  test('wrong week count is reported', () {
    expect(
      monthlyReportFormatProblem(_reportWithWeeks(2), period),
      allOf(contains('expected 4 week sections'), contains('found 2')),
    );
  });

  test('repair prompt carries the problem, format, and previous answer', () {
    final prompt = buildFormatRepairPrompt(
      previousAnswer: 'OLD ANSWER',
      problem: 'missing weeks',
      outputFormat: 'FORMAT SPEC',
    );
    expect(prompt, contains('missing weeks'));
    expect(prompt, contains('FORMAT SPEC'));
    expect(prompt, endsWith('OLD ANSWER'));
    expect(parsedActionCount(_reportWithWeeks(3)), 3);
  });
}
