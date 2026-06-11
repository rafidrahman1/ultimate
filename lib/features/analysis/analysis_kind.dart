/// Distinguishes analysis run types.
enum AnalysisKind {
  /// Analyze current-month data and generate pattern insights.
  monthlyInsights,
}

extension AnalysisKindLabel on AnalysisKind {
  String get displayName => switch (this) {
        AnalysisKind.monthlyInsights => 'Monthly insights',
      };

  String get resultTitlePrefix => switch (this) {
        AnalysisKind.monthlyInsights => 'Monthly insights',
      };
}
