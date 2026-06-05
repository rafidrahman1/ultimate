import 'progress_review_models.dart';

abstract final class ProgressReviewParser {
  ProgressReviewParser._();

  static ProgressReviewParsedReport parse(String rawMarkdown) {
    final trimmed = rawMarkdown.trim();
    if (trimmed.isEmpty) return const ProgressReviewParsedReport();

    var section = _ProgressSection.none;
    String? checklistAdherence;
    String? dataBackedSummary;
    String? overallScore;
    final domains = <ProgressReviewDomain>[];
    final whatWorked = <ProgressReviewBullet>[];
    final gaps = <ProgressReviewBullet>[];

    var currentDomainName = '';
    var currentTarget = '';
    var currentOutcome = '';
    var currentVerdict = '';
    var currentScore = '';
    var currentDelta = '';

    void flushDomain() {
      if (currentDomainName.isEmpty) return;
      domains.add(
        ProgressReviewDomain(
          name: currentDomainName,
          checklistTarget: _nullable(currentTarget),
          actualOutcome: _nullable(currentOutcome),
          verdict: _nullable(currentVerdict),
          score: _nullable(currentScore),
          delta: _nullable(currentDelta),
        ),
      );
      currentDomainName = '';
      currentTarget = '';
      currentOutcome = '';
      currentVerdict = '';
      currentScore = '';
      currentDelta = '';
    }

    for (final rawLine in trimmed.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line == '---') continue;

      if (_isDomainHeader(line)) {
        flushDomain();
        currentDomainName = _headerTitle(line);
        section = _ProgressSection.domains;
        continue;
      }

      if (_isMajorHeader(line)) {
        flushDomain();
        section = _sectionFromTitle(_headerTitle(line));
        continue;
      }

      if (!_isBulletLine(line)) continue;

      final bullet = _parseBoldBullet(line);
      if (bullet == null) continue;

      switch (section) {
        case _ProgressSection.overall:
          switch (_normalizeLabel(bullet.title)) {
            case 'checklist adherence':
              checklistAdherence = bullet.description;
            case 'data-backed summary':
              dataBackedSummary = bullet.description;
            case 'overall score':
              overallScore = bullet.description;
          }
        case _ProgressSection.domains:
          switch (_normalizeLabel(bullet.title)) {
            case 'checklist target':
              currentTarget = bullet.description;
            case 'actual outcome':
              currentOutcome = bullet.description;
            case 'verdict':
              currentVerdict = bullet.description;
            case 'score':
              currentScore = bullet.description;
            case 'delta':
              currentDelta = bullet.description;
          }
        case _ProgressSection.worked:
          whatWorked.add(
            ProgressReviewBullet(
              title: bullet.title,
              description: bullet.description,
            ),
          );
        case _ProgressSection.gaps:
          gaps.add(
            ProgressReviewBullet(
              title: bullet.title,
              description: bullet.description,
            ),
          );
        case _ProgressSection.none:
          break;
      }
    }

    flushDomain();

    return ProgressReviewParsedReport(
      checklistAdherence: checklistAdherence,
      dataBackedSummary: dataBackedSummary,
      overallScore: overallScore,
      domains: domains,
      whatWorked: whatWorked,
      gaps: gaps,
    );
  }
}

enum _ProgressSection { none, overall, domains, worked, gaps }

_ProgressSection _sectionFromTitle(String title) {
  final normalized = title.toLowerCase();
  if (normalized.contains('overall improvement')) {
    return _ProgressSection.overall;
  }
  if (normalized.contains('domain progress')) {
    return _ProgressSection.domains;
  }
  if (normalized.contains('what worked')) {
    return _ProgressSection.worked;
  }
  if (normalized.contains('gaps')) {
    return _ProgressSection.gaps;
  }
  return _ProgressSection.none;
}

String? _nullable(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _normalizeLabel(String label) =>
    label.trim().toLowerCase().replaceAll(RegExp(r'[.:]+$'), '');

bool _isMajorHeader(String line) {
  if (line.startsWith('####')) return false;
  return RegExp(r'^#{1,3}\s').hasMatch(line);
}

bool _isDomainHeader(String line) {
  return line.startsWith('####') && !line.startsWith('#####');
}

bool _isBulletLine(String line) {
  return RegExp(r'^[\*\-]\s+').hasMatch(line) ||
      RegExp(r'^\d+\.\s+\*\*').hasMatch(line);
}

String _headerTitle(String line) {
  var title = line.replaceFirst(RegExp(r'^#{1,6}\s*'), '').trim();
  title = title.replaceFirst(RegExp(r'^\d+\.\s*'), '');
  return title.replaceAll('**', '').trim();
}

({String title, String description})? _parseBoldBullet(String line) {
  var body = line.trim();
  body = body.replaceFirst(RegExp(r'^[\*\-]\s+'), '');
  body = body.replaceFirst(RegExp(r'^\d+\.\s+'), '');
  body = body.trim();

  final match =
      RegExp(r'^\*\*([^*]+)\*\*:?\s*(.*)$', dotAll: true).firstMatch(body);
  if (match == null) {
    final plain = body.replaceAll('**', '').trim();
    if (plain.isEmpty) return null;
    return (title: plain, description: '');
  }

  var title = _cleanValue(match.group(1) ?? '');
  if (title.endsWith(':')) {
    title = title.substring(0, title.length - 1).trim();
  }
  final description = _cleanValue(match.group(2) ?? '');
  if (title.isEmpty) return null;
  return (title: title, description: description);
}

String _cleanValue(String value) => value.replaceAll('**', '').trim();
