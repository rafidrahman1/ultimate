import 'package:personal/features/results/legacy_insight_models.dart';
import 'package:personal/features/results/insight_text.dart';

class InsightSection {
  const InsightSection({
    required this.title,
    this.bullets = const [],
    this.paragraph,
  });

  final String title;
  final List<String> bullets;
  final String? paragraph;

  bool get hasBullets => bullets.isNotEmpty;
}

InsightReport parseInsightReport(String output) {
  final trimmed = output.trim();
  if (trimmed.isEmpty) {
    return const InsightReport(sections: []);
  }

  final majors = <InsightMajorSection>[];
  var currentKind = InsightSectionKind.other;
  var currentMajorTitle = '';
  final subsections = <InsightSubsection>[];
  var currentSubTitle = '';
  var currentDomain = InsightDomain.general;
  var currentBullets = <InsightBullet>[];

  void flushSubsection() {
    if (currentBullets.isEmpty && currentSubTitle.isEmpty) return;
    final title = currentSubTitle.isNotEmpty ? currentSubTitle : _defaultSubTitle(currentKind);
    subsections.add(
      InsightSubsection(
        title: title,
        domain: currentDomain,
        bullets: List.unmodifiable(currentBullets),
      ),
    );
    currentBullets = [];
    currentSubTitle = '';
  }

  void flushMajor() {
    flushSubsection();
    if (subsections.isEmpty) return;
    majors.add(
      InsightMajorSection(
        title: currentMajorTitle.isNotEmpty ? currentMajorTitle : 'Insights',
        kind: currentKind,
        subsections: List.unmodifiable(subsections),
      ),
    );
    subsections.clear();
  }

  for (final rawLine in trimmed.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (_isMajorHeader(line)) {
      flushMajor();
      currentMajorTitle = _headerTitle(line);
      currentKind = kindFromTitle(currentMajorTitle);
      continue;
    }

    if (_isSubHeader(line)) {
      flushSubsection();
      currentSubTitle = _headerTitle(line);
      currentDomain = domainFromTitle(currentSubTitle);
      continue;
    }

    if (_isBulletLine(line)) {
      final bullet = _parseBulletLine(line);
      if (currentKind == InsightSectionKind.patterns && currentSubTitle.isEmpty) {
        currentSubTitle = bullet.headline ?? 'Patterns';
        currentDomain = _domainForPatternBullet(bullet);
      }
      currentBullets.add(bullet);
      continue;
    }

    if (!_looksLikeIntro(line) && currentBullets.isEmpty && subsections.isEmpty) {
      continue;
    }
  }

  flushMajor();
  if (majors.isEmpty) {
    return _fallbackFromLegacy(trimmed);
  }
  return InsightReport(sections: majors);
}

InsightReport _fallbackFromLegacy(String output) {
  final legacy = parseInsightOutput(output);
  if (legacy.isEmpty) return const InsightReport(sections: []);

  final sections = legacy.map((section) {
    final kind = kindFromTitle(section.title);
    final bullets = section.bullets.map(_parseBulletLine).toList();
    if (section.paragraph != null && section.paragraph!.isNotEmpty) {
      bullets.insert(0, InsightBullet(body: section.paragraph!));
    }
    return InsightMajorSection(
      title: section.title,
      kind: kind,
      subsections: [
        InsightSubsection(
          title: section.title,
          domain: domainFromTitle(section.title),
          bullets: bullets,
        ),
      ],
    );
  }).toList();

  return InsightReport(sections: sections);
}

List<InsightSection> parseInsightOutput(String output) {
  final report = parseInsightReport(output);
  return report.sections
      .map(
        (major) => InsightSection(
          title: major.title,
          bullets: [
            for (final sub in major.subsections)
              for (final b in sub.bullets) b.displayText,
          ],
          paragraph: null,
        ),
      )
      .toList();
}

String insightPreview(String output, {int maxLength = 140}) {
  final report = parseInsightReport(output);
  for (final major in report.sections) {
    for (final sub in major.subsections) {
      for (final bullet in sub.bullets) {
        final text = stripMarkdown(bullet.displayText);
        if (text.isEmpty) continue;
        if (text.length <= maxLength) return text;
        return '${text.substring(0, maxLength)}…';
      }
    }
  }
  final flat = stripMarkdown(output.replaceAll('\n', ' '));
  if (flat.length <= maxLength) return flat;
  return '${flat.substring(0, maxLength)}…';
}

bool _isMajorHeader(String line) {
  final cleaned = _stripHashes(line);
  if (line.startsWith('####')) return false;
  if (line.startsWith('###') || line.startsWith('##')) return true;
  final lower = cleaned.toLowerCase();
  if (_knownHeaders.any((h) => lower.startsWith(h) || lower == h)) {
    return cleaned.length < 90;
  }
  if (lower.contains('pattern') ||
      lower.contains('anomal') ||
      lower.contains('next action') ||
      lower.contains('action plan')) {
    return cleaned.length < 90;
  }
  if (line.endsWith(':') && cleaned.length < 60 && !line.contains('. ')) {
    return true;
  }
  if (RegExp(r'^[A-Za-z][\w\s&\-]+:').hasMatch(cleaned) &&
      cleaned.length < 60 &&
      !line.contains('. ')) {
    return true;
  }
  return !line.contains('. ') &&
      cleaned.length < 48 &&
      RegExp(r'^[A-Za-z][\w\s&\-]+$').hasMatch(cleaned);
}

bool _isSubHeader(String line) {
  if (line.startsWith('####')) return true;
  final cleaned = _stripHashes(line);
  return RegExp(r'^\d+\.\s').hasMatch(cleaned) && cleaned.length < 100;
}

bool _isBulletLine(String line) {
  if (RegExp(r'^[\*\-]\s+').hasMatch(line)) return true;
  if (RegExp(r'^\*\s+\*\*').hasMatch(line)) return true;
  if (RegExp(r'^\d+\.\s+\*\*').hasMatch(line)) return true;
  return false;
}

bool _looksLikeIntro(String line) {
  final lower = line.toLowerCase();
  return lower.startsWith('here is your') ||
      lower.startsWith('this is your') ||
      lower.contains('personalized insights');
}

String _stripHashes(String line) {
  return line.replaceFirst(RegExp(r'^#{1,6}\s*'), '').trim();
}

String _headerTitle(String line) {
  var title = _stripHashes(line);
  title = title.replaceFirst(RegExp(r'^\d+\.\s*'), '');
  return stripMarkdown(title);
}

String _defaultSubTitle(InsightSectionKind kind) {
  return switch (kind) {
    InsightSectionKind.patterns => 'Patterns',
    InsightSectionKind.actions => 'Actions',
    InsightSectionKind.other => 'Insights',
  };
}

InsightDomain _domainForPatternBullet(InsightBullet bullet) {
  final text = '${bullet.headline ?? ''} ${bullet.body}'.toLowerCase();
  return domainFromTitle(text);
}

InsightBullet _parseBulletLine(String line) {
  var body = line.trim();
  body = body.replaceFirst(RegExp(r'^[\*\-]\s+'), '');
  body = body.replaceFirst(RegExp(r'^\d+\.\s+'), '');
  body = body.trim();

  String? headline;
  final headMatch = RegExp(r'^\*\*([^*]+)\*\*:?\s*(.*)$', dotAll: true).firstMatch(body);
  if (headMatch != null) {
    headline = stripMarkdown(headMatch.group(1)!);
    body = headMatch.group(2)?.trim() ?? '';
  }

  final highlights = _extractHighlights('$headline $body');
  return InsightBullet(
    headline: headline?.isEmpty == true ? null : headline,
    body: body,
    highlights: highlights,
  );
}

List<String> _extractHighlights(String text) {
  final highlights = <String>[];
  final seen = <String>{};
  for (final match in RegExp(r'\*\*([^*]+)\*\*').allMatches(text)) {
    final value = match.group(1)?.trim() ?? '';
    if (value.isEmpty) continue;
    final key = value.toLowerCase();
    if (seen.contains(key)) continue;
    if (!_looksLikeMetric(value) && !value.contains('"')) continue;
    seen.add(key);
    highlights.add(value);
  }
  return highlights;
}

bool _looksLikeMetric(String value) {
  if (!RegExp(r'\d').hasMatch(value)) return false;
  final lower = value.toLowerCase();
  return lower.contains('bdt') ||
      lower.contains('bpm') ||
      lower.contains('km') ||
      lower.contains('step') ||
      lower.contains('trip') ||
      RegExp(r'\d\s*h').hasMatch(lower) ||
      RegExp(r'\d[,.]?\d*\s*m\b').hasMatch(lower) ||
      RegExp(r'^\d[\d,.]*$').hasMatch(value.trim());
}

const _knownHeaders = [
  'focus',
  'highlights',
  'next actions',
  'note',
  'summary',
];
