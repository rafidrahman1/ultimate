import 'insights_models.dart';

/// Lightweight parser for the fixed AI markdown insight format.
abstract final class InsightParser {
  InsightParser._();

  static InsightsParsedReport parse(String rawMarkdown) {
    final trimmed = rawMarkdown.trim();
    if (trimmed.isEmpty) {
      return const InsightsParsedReport();
    }

    final anomalies = <InsightAnomaly>[];
    final actions = <ActionDirective>[];

    var section = _ParseSection.none;
    var actionGroup = '';
    var actionCategory = InsightItemCategory.general;

    for (final rawLine in trimmed.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line == '---') continue;

      if (_isSubHeader(line)) {
        actionGroup = _headerTitle(line);
        actionCategory = InsightItemCategory.fromGroupHeader(actionGroup);
        continue;
      }

      if (_isMajorHeader(line)) {
        final title = _headerTitle(line).toLowerCase();
        if (title.contains('pattern') || title.contains('anomal')) {
          section = _ParseSection.patterns;
          actionGroup = '';
        } else if (title.contains('action') || title.contains('next 7')) {
          section = _ParseSection.actions;
        } else {
          section = _ParseSection.none;
        }
        continue;
      }

      if (!_isBulletLine(line)) continue;

      final bullet = _parseBoldBullet(line);
      if (bullet == null) continue;

      switch (section) {
        case _ParseSection.patterns:
          final category = InsightItemCategory.fromKeywords(
            '${bullet.title} ${bullet.description}',
          );
          anomalies.add(
            InsightAnomaly(
              title: bullet.title,
              description: bullet.description,
              category: category.label,
            ),
          );
        case _ParseSection.actions:
          actions.add(
            ActionDirective(
              title: bullet.title,
              description: bullet.description,
              category: actionCategory.label,
              groupLabel: actionGroup.isEmpty ? null : actionGroup,
            ),
          );
        case _ParseSection.none:
          break;
      }
    }

    return InsightsParsedReport(anomalies: anomalies, actions: actions);
  }
}

enum _ParseSection { none, patterns, actions }

({String title, String description})? _parseBoldBullet(String line) {
  var body = line.trim();
  body = body.replaceFirst(RegExp(r'^[\*\-]\s+'), '');
  body = body.replaceFirst(RegExp(r'^\d+\.\s+'), '');
  body = body.trim();

  final match = RegExp(r'^\*\*([^*]+)\*\*:?\s*(.*)$', dotAll: true).firstMatch(body);
  if (match == null) {
    final plain = _stripInlineBold(body);
    if (plain.isEmpty) return null;
    return (title: plain, description: '');
  }

  var title = _stripInlineBold(match.group(1) ?? '').trim();
  if (title.endsWith(':')) title = title.substring(0, title.length - 1).trim();
  final description = (match.group(2) ?? '').trim();
  if (title.isEmpty) return null;
  return (title: title, description: description);
}

bool _isMajorHeader(String line) {
  if (line.startsWith('####')) return false;
  if (RegExp(r'^#{1,3}\s').hasMatch(line)) return true;
  final cleaned = _stripHashes(line).toLowerCase();
  if (cleaned.contains('pattern') ||
      cleaned.contains('anomal') ||
      cleaned.contains('next action')) {
    return cleaned.length < 90;
  }
  return false;
}

bool _isSubHeader(String line) {
  return line.startsWith('####');
}

bool _isBulletLine(String line) {
  return RegExp(r'^[\*\-]\s+').hasMatch(line) ||
      RegExp(r'^\d+\.\s+\*\*').hasMatch(line);
}

String _headerTitle(String line) {
  var title = _stripHashes(line);
  title = title.replaceFirst(RegExp(r'^\d+\.\s*'), '');
  return _stripInlineBold(title).trim();
}

String _stripHashes(String line) {
  return line.replaceFirst(RegExp(r'^#{1,6}\s*'), '').trim();
}

String _stripInlineBold(String text) {
  return text
      .replaceAllMapped(
        RegExp(r'\*\*([^*]+)\*\*'),
        (m) => m.group(1) ?? '',
      )
      .trim();
}
