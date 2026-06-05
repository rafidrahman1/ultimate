import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analysis_reports_storage.dart';

class AnalysisResult {
  const AnalysisResult({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.prompt,
    required this.output,
    required this.dataSnapshot,
    this.aiProvider,
    this.aiModel,
  });

  final String id;
  final DateTime createdAt;
  final String title;
  final String prompt;
  final String output;
  final Map<String, String> dataSnapshot;

  /// `openai`, `gemini`, or `local` when API calls were off.
  final String? aiProvider;

  final String? aiModel;

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
        if (aiProvider != null) 'aiProvider': aiProvider,
        if (aiModel != null && aiModel!.isNotEmpty) 'aiModel': aiModel,
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
      aiProvider: json['aiProvider'] as String?,
      aiModel: json['aiModel'] as String?,
    );
  }
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
