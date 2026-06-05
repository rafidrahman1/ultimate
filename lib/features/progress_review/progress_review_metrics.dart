import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'progress_review_models.dart';

class ProgressReviewMetrics {
  const ProgressReviewMetrics({
    this.overallScore,
    this.adherenceCompleted,
    this.adherenceTotal,
    this.adherencePercent,
    this.domainScores = const [],
    this.comparisons = const [],
    this.highlights = const [],
    this.focusGaps = const [],
  });

  final int? overallScore;
  final int? adherenceCompleted;
  final int? adherenceTotal;
  final int? adherencePercent;
  final List<DomainScoreMetric> domainScores;
  final List<DomainComparisonMetric> comparisons;
  final List<VisualBulletMetric> highlights;
  final List<VisualBulletMetric> focusGaps;

  factory ProgressReviewMetrics.fromReport(ProgressReviewParsedReport report) {
    final adherence = _parseAdherence(report.checklistAdherence);
    final overall = _extractScore(report.overallScore);

    final domainScores = <DomainScoreMetric>[];
    final comparisons = <DomainComparisonMetric>[];

    for (final domain in report.domains) {
      final score = _extractScore(domain.score);
      domainScores.add(
        DomainScoreMetric(
          name: domain.name,
          score: score,
          verdict: domain.verdict,
          icon: _iconForDomain(domain.name),
          color: _colorHintForDomain(domain.name),
        ),
      );

      final comparison = _parseComparison(
        name: domain.name,
        targetText: domain.checklistTarget,
        outcomeText: domain.actualOutcome,
        deltaText: domain.delta,
        verdict: domain.verdict,
        score: score,
      );
      if (comparison != null) comparisons.add(comparison);
    }

    return ProgressReviewMetrics(
      overallScore: overall,
      adherenceCompleted: adherence?.$1,
      adherenceTotal: adherence?.$2,
      adherencePercent:
          adherence?.$3 ?? _extractPercent(report.checklistAdherence),
      domainScores: domainScores,
      comparisons: comparisons,
      highlights: report.whatWorked.map(_bulletToVisual).toList(),
      focusGaps: report.gaps.map(_bulletToVisual).toList(),
    );
  }
}

class DomainScoreMetric {
  const DomainScoreMetric({
    required this.name,
    required this.icon,
    required this.color,
    this.score,
    this.verdict,
  });

  final String name;
  final int? score;
  final String? verdict;
  final IconData icon;
  final Color color;
}

class DomainComparisonMetric {
  const DomainComparisonMetric({
    required this.name,
    required this.icon,
    required this.color,
    required this.actual,
    required this.target,
    required this.unit,
    required this.label,
    this.verdict,
    this.score,
    this.deltaLabel,
  });

  final String name;
  final double actual;
  final double target;
  final String unit;
  final String label;
  final String? verdict;
  final int? score;
  final String? deltaLabel;
  final IconData icon;
  final Color color;

  double get progress => target <= 0 ? 0 : (actual / target).clamp(0, 1.5);

  bool get underCap => unit == 'BDT' || unit == 'km' ? actual <= target : false;
}

class VisualBulletMetric {
  const VisualBulletMetric({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
}

(int completed, int total, int? percent)? _parseAdherence(String? raw) {
  if (raw == null) return null;
  final match =
      RegExp(r'(\d+)\s*of\s*(\d+)', caseSensitive: false).firstMatch(raw);
  if (match == null) return null;
  final completed = int.tryParse(match.group(1)!);
  final total = int.tryParse(match.group(2)!);
  if (completed == null || total == null) return null;
  final percent = total == 0 ? 0 : ((completed / total) * 100).round();
  return (completed, total, percent);
}

int? _extractPercent(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'(\d{1,3})\s*%').firstMatch(raw);
  return match == null ? null : int.tryParse(match.group(1)!);
}

int? _extractScore(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'(\d{1,3})\s*/\s*100').firstMatch(raw);
  if (match != null) return int.tryParse(match.group(1)!);
  final plain = RegExp(r'^\d{1,3}$').firstMatch(raw.trim());
  if (plain != null) return int.tryParse(plain.group(0)!);
  return null;
}

DomainComparisonMetric? _parseComparison({
  required String name,
  required String? targetText,
  required String? outcomeText,
  required String? deltaText,
  required String? verdict,
  required int? score,
}) {
  final icon = _iconForDomain(name);
  final color = _colorHintForDomain(name);

  final spend = _firstMoneyPair(targetText, outcomeText);
  if (spend != null) {
    return DomainComparisonMetric(
      name: name,
      actual: spend.actual,
      target: spend.target,
      unit: 'BDT',
      label: 'Spending',
      verdict: verdict,
      score: score,
      deltaLabel: _shortDelta(deltaText),
      icon: icon,
      color: color,
    );
  }

  final steps = _firstNumericPair(
    targetText,
    outcomeText,
    pattern: RegExp(
      r'([\d,]+)\s*(?:steps?)?/day',
      caseSensitive: false,
    ),
  );
  if (steps != null) {
    return DomainComparisonMetric(
      name: name,
      actual: steps.actual,
      target: steps.target,
      unit: 'steps',
      label: 'Daily steps',
      verdict: verdict,
      score: score,
      deltaLabel: _shortDelta(deltaText),
      icon: icon,
      color: color,
    );
  }

  final distance = _firstNumericPair(
    targetText,
    outcomeText,
    pattern: RegExp(r'([\d.]+)\s*km', caseSensitive: false),
  );
  if (distance != null) {
    return DomainComparisonMetric(
      name: name,
      actual: distance.actual,
      target: distance.target,
      unit: 'km',
      label: 'Distance',
      verdict: verdict,
      score: score,
      deltaLabel: _shortDelta(deltaText),
      icon: icon,
      color: color,
    );
  }

  if (score != null) {
    return DomainComparisonMetric(
      name: name,
      actual: score.toDouble(),
      target: 100,
      unit: 'pts',
      label: 'Score',
      verdict: verdict,
      score: score,
      deltaLabel: _shortDelta(deltaText),
      icon: icon,
      color: color,
    );
  }

  return null;
}

({double actual, double target})? _firstMoneyPair(
  String? targetText,
  String? outcomeText,
) {
  final target = _firstNumber(
    targetText,
    RegExp(r'([\d,]+)\s*BDT', caseSensitive: false),
  );
  final actual = _firstNumber(
    outcomeText,
    RegExp(r'([\d,]+)\s*BDT', caseSensitive: false),
  );
  if (target == null || actual == null) return null;
  return (actual: actual, target: target);
}

({double actual, double target})? _firstNumericPair(
  String? targetText,
  String? outcomeText, {
  required RegExp pattern,
}) {
  final target = _firstNumber(targetText, pattern);
  final actual = _firstNumber(outcomeText, pattern);
  if (target == null || actual == null) return null;
  return (actual: actual, target: target);
}

double? _firstNumber(String? text, RegExp pattern) {
  if (text == null) return null;
  final match = pattern.firstMatch(text);
  if (match == null) return null;
  return double.tryParse(match.group(1)!.replaceAll(',', ''));
}

String? _shortDelta(String? delta) {
  if (delta == null) return null;
  final trimmed = delta.trim();
  if (trimmed.length <= 48) return trimmed;
  return '${trimmed.substring(0, 45)}...';
}

VisualBulletMetric _bulletToVisual(ProgressReviewBullet bullet) {
  final combined = '${bullet.title} ${bullet.description}';
  final number = _extractHighlightNumber(combined);
  return VisualBulletMetric(
    title: bullet.title,
    subtitle: bullet.description,
    value: number?.value ?? '—',
    unit: number?.unit ?? '',
    icon: _iconForBullet(bullet.title),
    color: _colorForBullet(bullet.title),
  );
}

({String value, String unit})? _extractHighlightNumber(String text) {
  final patterns = <RegExp, String>{
    RegExp(r'([\d.]+)\s*km'): 'km',
    RegExp(r'([\d,]+)\s*BDT'): 'BDT',
    RegExp(r'([\d,]+)\s*(?:steps?)?/day', caseSensitive: false): 'steps/day',
    RegExp(r'([\d.]+)\s*h(?:ours?)?', caseSensitive: false): 'h',
    RegExp(r'(\d{1,3})\s*%'): '%',
  };

  for (final entry in patterns.entries) {
    final match = entry.key.firstMatch(text);
    if (match != null) {
      return (value: match.group(1)!.replaceAll(',', ''), unit: entry.value);
    }
  }
  return null;
}

IconData _iconForDomain(String name) {
  final normalized = name.toLowerCase();
  if (normalized.contains('health') || normalized.contains('sleep')) {
    return Icons.favorite_rounded;
  }
  if (normalized.contains('expense')) {
    return Icons.account_balance_wallet_rounded;
  }
  if (normalized.contains('location') || normalized.contains('mobility')) {
    return Icons.route_rounded;
  }
  if (normalized.contains('gaming') || normalized.contains('leisure')) {
    return Icons.sports_esports_rounded;
  }
  if (normalized.contains('calendar') || normalized.contains('schedule')) {
    return Icons.calendar_month_rounded;
  }
  return Icons.insights_rounded;
}

Color _colorHintForDomain(String name) {
  final normalized = name.toLowerCase();
  if (normalized.contains('health') || normalized.contains('sleep')) {
    return AppColors.health;
  }
  if (normalized.contains('expense')) return AppColors.expenses;
  if (normalized.contains('location') || normalized.contains('mobility')) {
    return AppColors.location;
  }
  if (normalized.contains('gaming') || normalized.contains('leisure')) {
    return AppColors.gameActivity;
  }
  if (normalized.contains('calendar') || normalized.contains('schedule')) {
    return AppColors.calendar;
  }
  return AppColors.accent;
}

IconData _iconForBullet(String title) {
  final normalized = title.toLowerCase();
  if (normalized.contains('step')) return Icons.directions_walk_rounded;
  if (normalized.contains('sleep')) return Icons.bedtime_rounded;
  if (normalized.contains('spend') || normalized.contains('cash')) {
    return Icons.payments_rounded;
  }
  if (normalized.contains('mobility') || normalized.contains('motor')) {
    return Icons.two_wheeler_rounded;
  }
  if (normalized.contains('tech') || normalized.contains('purchase')) {
    return Icons.devices_rounded;
  }
  return Icons.flag_rounded;
}

Color _colorForBullet(String title) {
  final normalized = title.toLowerCase();
  if (normalized.contains('gap') ||
      normalized.contains('sleep') ||
      normalized.contains('step')) {
    return AppColors.health;
  }
  if (normalized.contains('spend') || normalized.contains('tech')) {
    return AppColors.expenses;
  }
  if (normalized.contains('mobility')) return AppColors.location;
  return AppColors.accent;
}
