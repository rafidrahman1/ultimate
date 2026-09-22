import 'package:intl/intl.dart';

import 'package:personal/features/analysis/analysis_period.dart';

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
  section('Gaming & Screen Time', dataSnapshot['gameActivity']);
  section('Calendar & Schedule', dataSnapshot['calendar']);
  section('Derived Metrics', dataSnapshot['derivedMetrics']);
  section('Goal Tracking', dataSnapshot['goalTracking']);

  return buffer.toString().trimRight();
}
