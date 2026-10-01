import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/results/insights_parser.dart';

/// Why [output] doesn't match the monthly-insights Markdown structure the
/// parser needs, or null when it does.
String? monthlyReportFormatProblem(String output, AnalysisPeriod period) {
  final report = InsightsReportParser.parse(output);
  if (report.actions.isEmpty) {
    return 'no checklist actions were found under "Clear Next Actions"';
  }

  final expected = period.checklistWeekCount;
  final found = report.weeks
      .map((week) => week.weekNumber)
      .whereType<int>()
      .toSet()
      .length;
  if (found != expected) {
    return 'expected $expected week sections '
        '("##### **Week N · ...**" headers) but found $found';
  }
  return null;
}

/// Number of checklist actions the parser finds; used to keep whichever of
/// the original and repaired answers is more usable.
int parsedActionCount(String output) =>
    InsightsReportParser.parse(output).actions.length;

String buildFormatRepairPrompt({
  required String previousAnswer,
  required String problem,
  required String outputFormat,
}) {
  return '''
Your previous answer did not follow the required output format: $problem.

Rewrite the answer below so it follows the REQUIRED OUTPUT FORMAT exactly. Keep every finding, number, and recommendation from it; do not add new claims and do not drop content. Output only the rewritten report.

REQUIRED OUTPUT FORMAT:
$outputFormat

PREVIOUS ANSWER:
$previousAnswer''';
}
