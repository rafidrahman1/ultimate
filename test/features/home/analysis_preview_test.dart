import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/home/analysis_data_preview.dart';

AnalysisDataSourcePreview _source(AnalysisDataSourceId id, String text) =>
    AnalysisDataSourcePreview(
      id: id,
      label: id.name,
      icon: Icons.circle,
      hasData: true,
      detail: '',
      promptText: text,
    );

void main() {
  AnalysisRunPreview preview(String engine) => AnalysisRunPreview(
    period: AnalysisPeriod.forReference(DateTime(2026, 5, 10)),
    sources: [
      _source(AnalysisDataSourceId.health, 'a' * 400),
      _source(AnalysisDataSourceId.expenses, 'b' * 40),
    ],
    insightEngineLabel: engine,
  );

  test('estimates tokens only for included sources, honouring overrides', () {
    final p = preview('Cloud AI (OpenAI · gpt)');
    expect(p.estimatedTokens({AnalysisDataSourceId.health}), 100);
    expect(
      p.estimatedTokens(
        {AnalysisDataSourceId.health, AnalysisDataSourceId.expenses},
        {AnalysisDataSourceId.expenses: 'c' * 8},
      ),
      102,
    );
    expect(p.estimatedTokens({}), 0);
  });

  test('only cloud engines count as leaving the device', () {
    expect(preview('Cloud AI (Gemini · x)').sendsToCloud, isTrue);
    expect(preview('On-device insights').sendsToCloud, isFalse);
  });
}
