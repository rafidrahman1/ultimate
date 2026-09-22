import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/results/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

/// Sends the raw export markdown to the user's configured AI provider and
/// returns a rewritten, curated version. Every specific fact in the raw
/// data is preserved by instruction, but the AI is free to reorganize and
/// tighten the writing.
Future<String> curateExportMarkdown({
  required AiSettings aiSettings,
  required String rawMarkdown,
  required AnalysisPeriod period,
}) async {
  const client = AiClient();
  final curated = await client.generate(
    settings: aiSettings,
    prompt: _buildCurationPrompt(rawMarkdown: rawMarkdown),
  );

  return '# Personal Data Export — ${period.dataRangeLabel} (AI-curated)\n\n'
      '${curated.trim()}';
}

String _buildCurationPrompt({required String rawMarkdown}) {
  return '''
You are helping organize a personal data export so it can be shared with another AI assistant for discussion.

Rewrite the data below into a clear, well-structured markdown document organized by category (Health, Expenses, Location & Mobility, Gaming & Screen Time, Calendar & Schedule, Derived Metrics, Goal Tracking). Preserve every specific number, date, and fact exactly as given — do not invent, estimate, or omit data. You may tighten phrasing, remove redundancy, and improve formatting. Do not add commentary, advice, or analysis of your own — just reorganize and clarify what's here.

RAW DATA:

$rawMarkdown
''';
}
