/// Distinguishes monthly insight runs from checklist progress reviews.
enum AnalysisKind {
  /// Analyze current-month data and generate patterns plus next-month checklist.
  monthlyInsights,

  /// Compare an existing checklist against current-month data for improvement.
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
