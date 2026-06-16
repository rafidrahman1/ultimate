import 'package:personal/features/results/insights_models.dart';

/// Parsed verdict for one checklist action.
class WeeklyVerificationItemResult {
  const WeeklyVerificationItemResult({
    required this.index,
    required this.title,
    required this.verdict,
    this.evidence,
    this.rationale,
  });

  final int index;
  final String title;
  final WeeklyVerificationVerdict verdict;
  final String? evidence;
  final String? rationale;
}

enum WeeklyVerificationVerdict { met, failed, unverified }

/// Aggregated parse result for a weekly verification run.
class WeeklyVerificationParseResult {
  const WeeklyVerificationParseResult({
    this.items = const [],
  });

  final List<WeeklyVerificationItemResult> items;

  Set<int> get completedIndices => {
        for (final item in items)
          if (item.verdict == WeeklyVerificationVerdict.met) item.index,
      };

  Set<int> get failedIndices => {
        for (final item in items)
          if (item.verdict == WeeklyVerificationVerdict.failed) item.index,
      };

  Set<int> get unverifiedIndices => {
        for (final item in items)
          if (item.verdict == WeeklyVerificationVerdict.unverified) item.index,
      };
}

abstract final class WeeklyChecklistVerificationParser {
  WeeklyChecklistVerificationParser._();

  static WeeklyVerificationParseResult parse(
    String rawMarkdown, {
    required List<ActionDirective> actions,
  }) {
    final trimmed = rawMarkdown.trim();
    if (trimmed.isEmpty) {
      return const WeeklyVerificationParseResult();
    }

    final items = <WeeklyVerificationItemResult>[];
    final matchedIndices = <int>{};

    for (final rawLine in trimmed.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final item = _parseLine(line, actions: actions);
      if (item == null) continue;
      if (matchedIndices.contains(item.index)) continue;
      matchedIndices.add(item.index);
      items.add(item);
    }

    return WeeklyVerificationParseResult(items: items);
  }
}

WeeklyVerificationItemResult? _parseLine(
  String line, {
  required List<ActionDirective> actions,
}) {
  final numbered = RegExp(
    r'^(\d+)\.\s*\*\*(.+?)\*\*\s*[—–-]\s*\*\*Verdict:\*\*\s*(Met|Failed|Unverified)',
    caseSensitive: false,
  ).firstMatch(line);

  if (numbered != null) {
    final index = int.parse(numbered.group(1)!) - 1;
    if (index < 0 || index >= actions.length) return null;
    return WeeklyVerificationItemResult(
      index: index,
      title: numbered.group(2)!.trim(),
      verdict: _parseVerdict(numbered.group(3)!),
    );
  }

  final titleVerdict = RegExp(
    r'^\*\*(.+?)\*\*\s*[—–-]\s*\*\*Verdict:\*\*\s*(Met|Failed|Unverified)',
    caseSensitive: false,
  ).firstMatch(line);

  if (titleVerdict != null) {
    final title = titleVerdict.group(1)!.trim();
    final index = _indexForTitle(title, actions);
    if (index == null) return null;
    return WeeklyVerificationItemResult(
      index: index,
      title: title,
      verdict: _parseVerdict(titleVerdict.group(2)!),
    );
  }

  return null;
}

WeeklyVerificationVerdict _parseVerdict(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'met') return WeeklyVerificationVerdict.met;
  if (normalized == 'failed') return WeeklyVerificationVerdict.failed;
  return WeeklyVerificationVerdict.unverified;
}

int? _indexForTitle(String title, List<ActionDirective> actions) {
  final normalized = title.toLowerCase();
  for (var i = 0; i < actions.length; i++) {
    if (actions[i].title.trim().toLowerCase() == normalized) return i;
  }
  for (var i = 0; i < actions.length; i++) {
    final actionTitle = actions[i].title.trim().toLowerCase();
    if (actionTitle.contains(normalized) || normalized.contains(actionTitle)) {
      return i;
    }
  }
  return null;
}
