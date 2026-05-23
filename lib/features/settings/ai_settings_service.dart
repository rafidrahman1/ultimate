import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _aiSettingsStorageKey = 'ai_settings_v1';

enum AiProvider { openai, gemini }

class AiSettings {
  const AiSettings({
    required this.provider,
    required this.openAiApiKey,
    required this.openAiModel,
    required this.geminiApiKey,
    required this.geminiModel,
    required this.enableApiCalls,
  });

  final AiProvider provider;
  final String openAiApiKey;
  final String openAiModel;
  final String geminiApiKey;
  final String geminiModel;
  final bool enableApiCalls;

  factory AiSettings.initial() {
    return const AiSettings(
      provider: AiProvider.openai,
      openAiApiKey: '',
      openAiModel: 'gpt-4o-mini',
      geminiApiKey: '',
      geminiModel: 'gemini-1.5-flash',
      enableApiCalls: true,
    );
  }

  AiSettings copyWith({
    AiProvider? provider,
    String? openAiApiKey,
    String? openAiModel,
    String? geminiApiKey,
    String? geminiModel,
    bool? enableApiCalls,
  }) {
    return AiSettings(
      provider: provider ?? this.provider,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      openAiModel: openAiModel ?? this.openAiModel,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      enableApiCalls: enableApiCalls ?? this.enableApiCalls,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'openAiApiKey': openAiApiKey,
        'openAiModel': openAiModel,
        'geminiApiKey': geminiApiKey,
        'geminiModel': geminiModel,
        'enableApiCalls': enableApiCalls,
      };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    final providerName = json['provider'] as String?;
    AiProvider? provider;
    for (final value in AiProvider.values) {
      if (value.name == providerName) {
        provider = value;
        break;
      }
    }
    return AiSettings(
      provider: provider ?? AiProvider.openai,
      openAiApiKey: json['openAiApiKey'] as String? ?? '',
      openAiModel: json['openAiModel'] as String? ?? AiSettings.initial().openAiModel,
      geminiApiKey: json['geminiApiKey'] as String? ?? '',
      geminiModel: json['geminiModel'] as String? ?? AiSettings.initial().geminiModel,
      enableApiCalls: json['enableApiCalls'] as bool? ?? true,
    );
  }
}

final aiSettingsProvider = AsyncNotifierProvider<AiSettingsNotifier, AiSettings>(
  AiSettingsNotifier.new,
);

class AiSettingsNotifier extends AsyncNotifier<AiSettings> {
  @override
  Future<AiSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_aiSettingsStorageKey);
    if (raw == null || raw.isEmpty) return AiSettings.initial();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AiSettings.fromJson(decoded);
    } catch (_) {
      return AiSettings.initial();
    }
  }

  Future<void> save(AiSettings settings) async {
    state = AsyncData(settings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiSettingsStorageKey, jsonEncode(settings.toJson()));
  }

  Future<void> reset() => save(AiSettings.initial());
}
