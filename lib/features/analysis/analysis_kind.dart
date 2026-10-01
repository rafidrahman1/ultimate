/// Distinguishes analysis run types.
enum AnalysisKind {
  /// Analyze current-month data and generate pattern insights.
  monthlyInsights,

  /// Compare checklist targets against current-month data.
  progressReview,
}

extension AnalysisKindLabel on AnalysisKind {
  String get displayName => switch (this) {
    AnalysisKind.monthlyInsights => 'Monthly insights',
    AnalysisKind.progressReview => 'Progress review',
  };

  String get resultTitlePrefix => switch (this) {
    AnalysisKind.monthlyInsights => 'Monthly insights',
    AnalysisKind.progressReview => 'Progress review',
  };
}
