import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Variance direction for a discrepancy-matrix row.
enum VarianceTone { negative, positive, compliant, neutral }

/// One target-vs-actual metric line inside a domain card.
class DomainMetricLine {
  const DomainMetricLine({
    required this.label,
    required this.actual,
    required this.target,
    this.flagged = false,
  });

  final String label;
  final String actual;
  final String target;

  /// When true the line is rendered as a leakage / breach callout.
  final bool flagged;

  factory DomainMetricLine.fromJson(Map<String, dynamic> json) {
    return DomainMetricLine(
      label: json['label'] as String? ?? '',
      actual: json['actual'] as String? ?? '',
      target: json['target'] as String? ?? '',
      flagged: json['flagged'] as bool? ?? false,
    );
  }
}

/// A single domain breakdown card.
class DomainBreakdown {
  const DomainBreakdown({
    required this.name,
    required this.status,
    this.score,
    this.excluded = false,
    this.metrics = const [],
    this.baselineStats = const [],
    this.warning,
  });

  final String name;
  final String status;

  /// 0–100 domain score; null when excluded.
  final int? score;
  final bool excluded;
  final List<DomainMetricLine> metrics;

  /// Raw baseline figures shown for excluded domains (e.g. play time).
  final List<String> baselineStats;

  /// Optional warning badge text (e.g. missing compliance logs).
  final String? warning;

  double get progress => (score ?? 0).clamp(0, 100) / 100;

  factory DomainBreakdown.fromJson(Map<String, dynamic> json) {
    return DomainBreakdown(
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      score: (json['score'] as num?)?.toInt(),
      excluded: json['excluded'] as bool? ?? false,
      metrics: (json['metrics'] as List<dynamic>? ?? const [])
          .map((e) => DomainMetricLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      baselineStats: (json['baselineStats'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      warning: json['warning'] as String?,
    );
  }
}

/// One row in the discrepancy matrix table.
class DiscrepancyRow {
  const DiscrepancyRow({
    required this.domain,
    required this.benchmark,
    required this.actual,
    required this.variance,
    required this.tone,
  });

  final String domain;
  final String benchmark;
  final String actual;
  final String variance;
  final VarianceTone tone;

  factory DiscrepancyRow.fromJson(Map<String, dynamic> json) {
    return DiscrepancyRow(
      domain: json['domain'] as String? ?? '',
      benchmark: json['benchmark'] as String? ?? '',
      actual: json['actual'] as String? ?? '',
      variance: json['variance'] as String? ?? '',
      tone: _toneFromName(json['tone'] as String?),
    );
  }
}

VarianceTone _toneFromName(String? raw) {
  return switch (raw) {
    'positive' => VarianceTone.positive,
    'compliant' => VarianceTone.compliant,
    'neutral' => VarianceTone.neutral,
    _ => VarianceTone.negative,
  };
}

/// Full, UI-ready progress review model parsed from the analysis report JSON.
class ProgressReviewViewData {
  const ProgressReviewViewData({
    required this.id,
    required this.title,
    required this.overallScore,
    required this.summary,
    required this.domains,
    required this.discrepancies,
  });

  final String id;
  final String title;
  final int overallScore;
  final String summary;
  final List<DomainBreakdown> domains;
  final List<DiscrepancyRow> discrepancies;

  factory ProgressReviewViewData.fromJson(Map<String, dynamic> json) {
    return ProgressReviewViewData(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Progress Review',
      overallScore: (json['overallScore'] as num?)?.toInt() ?? 0,
      summary: json['summary'] as String? ?? '',
      domains: (json['domains'] as List<dynamic>? ?? const [])
          .map((e) => DomainBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      discrepancies: (json['discrepancies'] as List<dynamic>? ?? const [])
          .map((e) => DiscrepancyRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Hardcoded mock parsed from analysis-report-1780667247226943-8125.json.
  factory ProgressReviewViewData.mock() {
    return ProgressReviewViewData.fromJson(
      jsonDecode(_mockReportJson) as Map<String, dynamic>,
    );
  }
}

/// Mock state notifier for the progress view (swap for live parsing later).
final progressReviewViewProvider =
    StateProvider<ProgressReviewViewData>((ref) {
  return ProgressReviewViewData.mock();
});

/// Derived from analysis-report-1780667247226943-8125.json, shaped for the UI.
const String _mockReportJson = '''
{
  "id": "1780667247226943-8125",
  "title": "Progress Review · June 2026",
  "overallScore": 34,
  "summary": "Spending stayed below the hard monthly cap, but sleep, steps, and mobility targets were not met, and the largest expense was a tech purchase that directly conflicted with the checklist. Steps averaged just 532/day against a 3,705–5,705 target, and the only logged night showed a 03:13 bedtime with 5h 36m sleep.",
  "domains": [
    {
      "name": "Health & Sleep",
      "status": "Declined",
      "score": 8,
      "metrics": [
        { "label": "Daily Steps", "actual": "532", "target": "3,705–5,705" },
        { "label": "Bedtime", "actual": "03:13", "target": "01:00–01:30" },
        { "label": "Sleep Duration", "actual": "5h 36m", "target": ">= 6h" }
      ]
    },
    {
      "name": "Expenses",
      "status": "Partial",
      "score": 62,
      "metrics": [
        { "label": "Total Outlays", "actual": "3,813 BDT", "target": "15,000 BDT cap" },
        { "label": "Leakage · Cursor Pro", "actual": "2,683 BDT on Jun 1", "target": "0 BDT (cooling-off)", "flagged": true }
      ]
    },
    {
      "name": "Location & Mobility",
      "status": "Improved",
      "score": 78,
      "metrics": [
        { "label": "Distance", "actual": "86.75 km", "target": "100–110 km cap" },
        { "label": "Fuel", "actual": "400 BDT", "target": "1,500 BDT ceiling" }
      ]
    },
    {
      "name": "Gaming & Leisure",
      "status": "N/A",
      "excluded": true,
      "baselineStats": [
        "5h 10m total play time",
        "5h 6m on Valorant"
      ]
    },
    {
      "name": "Calendar & Schedule",
      "status": "Unverifiable",
      "score": 40,
      "metrics": [
        { "label": "Verified Events", "actual": "Friends Meet · Muharram · Ashura", "target": "Attendance + routine anchors" }
      ],
      "warning": "Missing compliance walk logs"
    }
  ],
  "discrepancies": [
    { "domain": "Step Activity", "benchmark": "3,705–5,705 /day", "actual": "532 /day", "variance": "-3,173 steps/day", "tone": "negative" },
    { "domain": "Bedtime Lock", "benchmark": "01:00–01:30", "actual": "03:13", "variance": "+1h 43m drift", "tone": "negative" },
    { "domain": "Total Outlays", "benchmark": "15,000 BDT cap", "actual": "3,813 BDT", "variance": "-11,187.00 BDT", "tone": "positive" },
    { "domain": "Tech Spend", "benchmark": "0 BDT (cooling-off)", "actual": "2,683 BDT", "variance": "+2,683.00 BDT breach", "tone": "negative" },
    { "domain": "Travel Distance", "benchmark": "100 km cap", "actual": "86.75 km", "variance": "Compliant", "tone": "compliant" }
  ]
}
''';
