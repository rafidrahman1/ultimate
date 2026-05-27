import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prompt_template_sections.dart';

const _promptConfigStorageKey = 'prompt_config_v2';
const _legacyPromptConfigStorageKey = 'prompt_config_v1';

class PromptConfig {
  const PromptConfig({required this.preamble, required this.focus});

  /// Editable intro: role, tone, and core context before analysis rules.
  final String preamble;
  final String focus;

  /// Full template sent to the model (preamble + locked sections).
  String composeTemplate() {
    final parts = <String>[
      preamble.trim(),
      PromptTemplateSections.rulesForAnalysis,
      PromptTemplateSections.focusHeader,
      '{{focus}}',
      PromptTemplateSections.dataToAnalyze,
      PromptTemplateSections.outputFormat,
    ];
    return parts.join('\n\n');
  }

  factory PromptConfig.initial() {
    return const PromptConfig(
      preamble:
          'You are a highly analytical, uncompromising personal data assistant for Rafid Rahman.\n\n'
          'Balance empathy with strict candor. Do not sugarcoat poor metrics, excessive spending, or missed routines.\n\n'
          'CORE CONTEXT & BASELINES:\n\n'
          '- Profession & Schedule: Software Engineer L1 (Flutter Developer) at Catch Bangladesh LTD. Work days are Sunday to Thursday, 10 AM to 6 PM.\n\n'
          '- Financials: Monthly income is 35,000 BDT. Strict budget optimization is required. Provide exact fare breakdowns.\n\n'
          '- Fitness: The primary physical goal is maintaining a lean physique with visible abs. High baseline activity (NEAT) and adequate sleep are non-negotiable for recovery.\n\n'
          '- Household & Lifestyle: Married. I have three cats at home. Avoids social media. Enjoys making pizza at home and gaming.\n\n'
          '- Decision Support: For any tech/electronics detected in expenses (e.g., relating to hardware like the Mac Mini, MSI Thin 15, Galaxy ecosystem, or mechanical keyboards), provide strict "Buy or Skip" analysis to validate if the price was fair.',
      focus: 'Patterns, anomalies, and clear next actions for the next 7 days.',
    );
  }

  PromptConfig copyWith({String? preamble, String? focus}) {
    return PromptConfig(
      preamble: preamble ?? this.preamble,
      focus: focus ?? this.focus,
    );
  }

  Map<String, dynamic> toJson() => {'preamble': preamble, 'focus': focus};

  factory PromptConfig.fromJson(Map<String, dynamic> json) {
    return PromptConfig(
      preamble: json['preamble'] as String? ?? PromptConfig.initial().preamble,
      focus: json['focus'] as String? ?? PromptConfig.initial().focus,
    );
  }

  /// Migrates saved v1 full templates by keeping only the editable preamble.
  factory PromptConfig.fromLegacyJson(Map<String, dynamic> json) {
    final legacyTemplate = json['template'] as String?;
    final focus = json['focus'] as String? ?? PromptConfig.initial().focus;

    if (legacyTemplate == null || legacyTemplate.isEmpty) {
      return PromptConfig.initial().copyWith(focus: focus);
    }

    final rulesMarker = 'RULES FOR ANALYSIS:';
    final rulesIndex = legacyTemplate.indexOf(rulesMarker);
    final preamble = rulesIndex >= 0
        ? legacyTemplate.substring(0, rulesIndex).trim()
        : legacyTemplate.trim();

    return PromptConfig(
      preamble: preamble.isEmpty ? PromptConfig.initial().preamble : preamble,
      focus: focus,
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
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return PromptConfig.fromJson(decoded);
      } catch (_) {
        return PromptConfig.initial();
      }
    }

    final legacyRaw = prefs.getString(_legacyPromptConfigStorageKey);
    if (legacyRaw != null && legacyRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(legacyRaw) as Map<String, dynamic>;
        return PromptConfig.fromLegacyJson(decoded);
      } catch (_) {
        return PromptConfig.initial();
      }
    }

    return PromptConfig.initial();
  }

  Future<void> save(PromptConfig next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_promptConfigStorageKey, jsonEncode(next.toJson()));
  }

  Future<void> reset() => save(PromptConfig.initial());
}
