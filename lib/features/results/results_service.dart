import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_kind.dart';
import 'package:personal/features/analysis/analysis_reports_storage.dart';

class AnalysisResult {
  const AnalysisResult({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.prompt,
    required this.output,
    required this.dataSnapshot,
    this.dataMonthStart,
    this.aiProvider,
    this.aiModel,
    this.analysisKind = AnalysisKind.monthlyInsights,
  });

  final String id;
  final DateTime createdAt;
  final String title;
  final String prompt;
  final String output;
  final Map<String, String> dataSnapshot;

  /// First day of the calendar month whose data was analyzed.
  final DateTime? dataMonthStart;

  /// `openai`, `gemini`, or `local` when API calls were off.
  final String? aiProvider;

  final String? aiModel;

  final AnalysisKind analysisKind;

  String? get aiProviderLabel => switch (aiProvider) {
        'openai' => 'OpenAI',
        'gemini' => 'Gemini',
        'local' => 'Local',
        _ => null,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'title': title,
        'prompt': prompt,
        'output': output,
        'dataSnapshot': dataSnapshot,
        if (dataMonthStart != null)
          'dataMonthStart': dataMonthStart!.toIso8601String(),
        if (aiProvider != null) 'aiProvider': aiProvider,
        if (aiModel != null && aiModel!.isNotEmpty) 'aiModel': aiModel,
        if (analysisKind != AnalysisKind.monthlyInsights)
          'analysisKind': analysisKind.name,
      };

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawSnapshot = json['dataSnapshot'];
    return AnalysisResult(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      title: json['title'] as String? ?? 'Analysis',
      prompt: json['prompt'] as String? ?? '',
      output: json['output'] as String? ?? '',
      dataSnapshot: rawSnapshot is Map
          ? rawSnapshot.map(
              (key, value) => MapEntry('$key', value?.toString() ?? ''),
            )
          : const {},
      dataMonthStart: _parseDataMonthStart(json['dataMonthStart']),
      aiProvider: json['aiProvider'] as String?,
      aiModel: json['aiModel'] as String?,
      analysisKind: _parseAnalysisKind(json['analysisKind'] as String?),
    );
  }
}

AnalysisKind _parseAnalysisKind(String? raw) {
  if (raw == null || raw.isEmpty) return AnalysisKind.monthlyInsights;
  return AnalysisKind.values.firstWhere(
    (kind) => kind.name == raw,
    orElse: () => AnalysisKind.monthlyInsights,
  );
}

DateTime? _parseDataMonthStart(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final local = parsed.toLocal();
  return DateTime(local.year, local.month, 1);
}

final analysisResultsProvider =
    AsyncNotifierProvider<AnalysisResultsNotifier, List<AnalysisResult>>(
  AnalysisResultsNotifier.new,
);

class AnalysisResultsNotifier extends AsyncNotifier<List<AnalysisResult>> {
  final _storage = AnalysisReportsStorage.instance;

  @override
  Future<List<AnalysisResult>> build() async {
    try {
      final decoded = await _storage.loadAll();
      return decoded.map(AnalysisResult.fromJson).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return const [];
    }
  }

  Future<void> addResult(AnalysisResult result) async {
    final current = await future;
    final next = [result, ...current]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AsyncData(next);
    await _storage.save(result.toJson());
  }

  Future<void> deleteResult(String id) async {
    final current = await future;
    final next = current.where((result) => result.id != id).toList();
    state = AsyncData(next);
    await _storage.delete(id);
  }

  Future<void> clearAll() async {
    await future;
    state = const AsyncData([]);
    await _storage.clearAll();
  }
}
