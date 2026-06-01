import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _analysisResultsStorageKey = 'analysis_results_v1';

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
  @override
  Future<List<AnalysisResult>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_analysisResultsStorageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                AnalysisResult.fromJson(item.cast<String, dynamic>()),
          )
          .toList()
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
    await _persist(next);
  }

  Future<void> deleteResult(String id) async {
    final current = await future;
    final next = current.where((result) => result.id != id).toList();
    state = AsyncData(next);
    if (next.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_analysisResultsStorageKey);
    } else {
      await _persist(next);
    }
  }

  Future<void> clearAll() async {
    await future;
    state = const AsyncData([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_analysisResultsStorageKey);
  }

  Future<void> _persist(List<AnalysisResult> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = items.map((e) => e.toJson()).toList();
    await prefs.setString(_analysisResultsStorageKey, jsonEncode(jsonList));
  }
}
