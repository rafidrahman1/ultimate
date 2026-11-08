import 'package:intl/intl.dart';

import 'package:personal/core/period/analysis_period.dart';

/// Renders a data snapshot (as produced by `buildDataSnapshot`) into a
/// plain markdown file the user can hand to an external chatbot. Contains
/// only the raw per-source data — no AI instructions, output-format rules,
/// or personal-profile framing.
String buildExportMarkdown({
  required Map<String, String> dataSnapshot,
  required AnalysisPeriod period,
  required DateTime generatedAt,
}) {
  final generatedLabel = DateFormat('MMMM d, yyyy h:mm a').format(generatedAt);

  final buffer = StringBuffer()
    ..writeln('# Personal Data Export — ${period.dataRangeLabel}')
    ..writeln()
    ..writeln(
      'This is a personal data export from my Personal app, covering '
      '${period.dataRangeLabel}.',
    )
    ..writeln('Generated $generatedLabel.')
    ..writeln();

  void section(String title, String? body) {
    buffer
      ..writeln('## $title')
      ..writeln(body ?? 'No data available.')
      ..writeln();
  }

  section('Health', dataSnapshot['health']);
  section('Expenses', dataSnapshot['expenses']);
  section('Expense Categories', dataSnapshot['expenseCategories']);
  section('Location & Mobility', dataSnapshot['location']);
  section('Gaming', dataSnapshot['gameActivity']);
  section('Screen Time', dataSnapshot['screenTime']);
  section('Calendar & Schedule', dataSnapshot['calendar']);
  section('Cross-checks Between Sources', dataSnapshot['crossChecks']);
  section('Derived Metrics', dataSnapshot['derivedMetrics']);
  section('Goal Tracking', dataSnapshot['goalTracking']);

  return buffer.toString().trimRight();
}
