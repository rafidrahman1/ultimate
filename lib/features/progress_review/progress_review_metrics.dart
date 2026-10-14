import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/progress_review/progress_review_models.dart';

part 'progress_review_metric_models.dart';

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
    this.summaryStatChips = const [],
    this.domainVisuals = const [],
  });

  final int? overallScore;
  final int? adherenceCompleted;
  final int? adherenceTotal;
  final int? adherencePercent;
  final List<DomainScoreMetric> domainScores;
  final List<DomainComparisonMetric> comparisons;
  final List<VisualBulletMetric> highlights;
  final List<VisualBulletMetric> focusGaps;
  final List<SummaryStatChip> summaryStatChips;
  final List<DomainVisualData> domainVisuals;

  factory ProgressReviewMetrics.fromReport(
    ProgressReviewParsedReport report, {
    DomainColors colors = DomainColors.dark,
  }) {
    final adherence = _parseAdherence(report.checklistAdherence);
    final overall = _extractScore(report.overallScore);

    final domainScores = <DomainScoreMetric>[];
    final comparisons = <DomainComparisonMetric>[];
    final domainVisuals = <DomainVisualData>[];

    for (final domain in report.domains) {
      if (domain.isExcluded) continue;

      final score = _extractScore(domain.score);
      domainScores.add(
        DomainScoreMetric(
          name: domain.name,
          score: score,
          verdict: domain.verdict,
          icon: _iconForDomain(domain.name),
          color: _colorHintForDomain(domain.name, colors),
        ),
      );

      final comparison = _parseComparison(
        name: domain.name,
        targetText: domain.checklistTarget,
        outcomeText: domain.actualOutcome,
        deltaText: domain.delta,
        verdict: domain.verdict,
        score: score,
        colors: colors,
      );
      if (comparison != null) comparisons.add(comparison);
      domainVisuals.add(
        DomainVisualData(
          domain: domain,
          comparison: comparison,
          targetStats: extractStats(domain.checklistTarget),
          outcomeStats: extractStats(domain.actualOutcome),
          delta: parseDeltaVisual(domain.delta, domain.verdict, colors: colors),
        ),
      );
    }

    final summaryStatChips = extractSummaryStats(
      report.dataBackedSummary,
      report.overallScore,
      colors: colors,
    );

    return ProgressReviewMetrics(
      overallScore: overall,
      adherenceCompleted: adherence?.$1,
      adherenceTotal: adherence?.$2,
      adherencePercent:
          adherence?.$3 ?? _extractPercent(report.checklistAdherence),
      domainScores: domainScores,
      comparisons: comparisons,
      highlights: report.whatWorked
          .map((b) => _bulletToVisual(b, colors))
          .toList(),
      focusGaps: report.gaps.map((b) => _bulletToVisual(b, colors)).toList(),
      summaryStatChips: summaryStatChips,
      domainVisuals: domainVisuals,
    );
  }
}
