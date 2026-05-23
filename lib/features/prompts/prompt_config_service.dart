import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _promptConfigStorageKey = 'prompt_config_v1';

class PromptConfig {
  const PromptConfig({
    required this.template,
    required this.focus,
  });

  final String template;
  final String focus;

  factory PromptConfig.initial() {
    return const PromptConfig(
      template:
          'You are my personal insights assistant. Analyze the provided health, '
          'expenses, location, and chat context.\n\n'
          'Focus instructions:\n{{focus}}\n\n'
          'Data:\n'
          '- Health:\n{{health}}\n\n'
          '- Expenses:\n{{expenses}}\n\n'
          '- Location:\n{{location}}\n\n'
          '- Chat:\n{{chat}}\n\n'
          'Return concise, practical, and actionable insights.',
      focus: 'Patterns, anomalies, and clear next actions for the next 7 days.',
    );
  }

  PromptConfig copyWith({
    String? template,
    String? focus,
  }) {
    return PromptConfig(
      template: template ?? this.template,
      focus: focus ?? this.focus,
    );
  }

  Map<String, dynamic> toJson() => {
        'template': template,
        'focus': focus,
      };

  factory PromptConfig.fromJson(Map<String, dynamic> json) {
    return PromptConfig(
      template: json['template'] as String? ?? PromptConfig.initial().template,
      focus: json['focus'] as String? ?? PromptConfig.initial().focus,
    );
  }
}

final promptConfigProvider =
    AsyncNotifierProvider<PromptConfigNotifier, PromptConfig>(
  PromptConfigNotifier.new,
);

class PromptConfigNotifier extends AsyncNotifier<PromptConfig> {
  @override
  Future<PromptConfig> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_promptConfigStorageKey);
    if (raw == null || raw.isEmpty) return PromptConfig.initial();

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return PromptConfig.fromJson(decoded);
    } catch (_) {
      return PromptConfig.initial();
    }
  }

  Future<void> save(PromptConfig next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_promptConfigStorageKey, jsonEncode(next.toJson()));
  }

  Future<void> reset() => save(PromptConfig.initial());
}
