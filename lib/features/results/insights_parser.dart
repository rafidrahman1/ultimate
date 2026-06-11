import 'package:personal/features/results/insights_models.dart';

/// Lightweight parser for the fixed AI markdown insight format.
abstract final class InsightsReportParser {
  InsightsReportParser._();

  static InsightsParsedReport parse(String rawMarkdown) {
    final trimmed = rawMarkdown.trim();
    if (trimmed.isEmpty) {
      return const InsightsParsedReport();
    }

    final anomalies = <InsightAnomaly>[];
    var inPatterns = false;

    for (final rawLine in trimmed.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line == '---') continue;

      if (_isMajorHeader(line)) {
        final title = _headerTitle(line).toLowerCase();
        inPatterns = title.contains('pattern') || title.contains('anomal');
        continue;
      }

      if (!inPatterns || !_isBulletLine(line)) continue;

      final bullet = _parseBoldBullet(line);
      if (bullet == null) continue;

      final category = InsightItemCategory.categorizeAnomaly(
        bullet.title,
        bullet.description,
      );
      anomalies.add(
        InsightAnomaly(
          title: bullet.title,
          description: bullet.description,
          category: category.label,
        ),
      );
    }

    return InsightsParsedReport(anomalies: anomalies);
  }
}

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

bool _isBulletLine(String line) {
  return RegExp(r'^[\*\-]\s+').hasMatch(line) ||
      RegExp(r'^\d+\.\s+\*\*').hasMatch(line);
}

String _stripHashes(String line) {
  return line.replaceFirst(RegExp(r'^#{1,6}\s*'), '').trim();
}

String _headerTitle(String line) {
  var title = _stripHashes(line);
  title = title.replaceFirst(RegExp(r'^\d+\.\s*'), '');
  return _stripInlineBold(title);
}

String _stripInlineBold(String text) {
  return text.replaceAll('**', '').trim();
}
