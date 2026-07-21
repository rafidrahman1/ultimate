enum AnalysisDataSourceId { health, expenses, location, gameActivity, calendar }

/// Which domains to include when evaluating cross-domain dashboard metrics.
class AnalysisSourceSelection {
  const AnalysisSourceSelection(this.included);

  final Set<AnalysisDataSourceId> included;

  factory AnalysisSourceSelection.all() => AnalysisSourceSelection(
    Set<AnalysisDataSourceId>.from(AnalysisDataSourceId.values),
  );

  bool includes(AnalysisDataSourceId id) => included.contains(id);

  bool get isEmpty => included.isEmpty;
}
