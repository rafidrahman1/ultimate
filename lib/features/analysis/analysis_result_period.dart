import 'package:personal/core/period/analysis_period.dart';
import 'package:personal/features/results/reports/results_service.dart';

extension AnalysisResultPeriod on AnalysisResult {
  /// Data month analyzed and the following checklist month for this saved result.
  AnalysisPeriod get analysisPeriod => AnalysisPeriod.forStoredResult(
    createdAt: createdAt,
    dataMonthStart: dataMonthStart,
    title: title,
  );
}
