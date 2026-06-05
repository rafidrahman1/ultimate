import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prompt_template_sections.dart';

const _promptConfigStorageKey = 'prompt_config_v2';
const _legacyPromptConfigStorageKey = 'prompt_config_v1';

class PromptConfig {
  const PromptConfig({
    required this.assistantIdentity,
    required this.toneInstruction,
    required this.professionAndSchedule,
    required this.monthlyIncomeBdt,
    required this.financialInstruction,
    required this.fitnessGoal,
    required this.householdLifestyle,
    required this.decisionSupportRule,
    required this.focus,
  });

  /// Editable system prompt fields.
  final String assistantIdentity;
  final String toneInstruction;
  final String professionAndSchedule;
  final String monthlyIncomeBdt;
  final String financialInstruction;
  final String fitnessGoal;
  final String householdLifestyle;
  final String decisionSupportRule;
  final String focus;

  /// System instruction sent with each API request.
  String composeSystemInstruction() {
    final identity = assistantIdentity.trim().isEmpty
        ? _defaultAssistantIdentity
        : assistantIdentity.trim();
    final tone = toneInstruction.trim().isEmpty
        ? _defaultToneInstruction
        : toneInstruction.trim();
    final profession = professionAndSchedule.trim().isEmpty
        ? _defaultProfessionAndSchedule
        : professionAndSchedule.trim();
    final income = monthlyIncomeBdt.trim().isEmpty
        ? _defaultMonthlyIncomeBdt
        : monthlyIncomeBdt.trim();
    final financial = financialInstruction.trim().isEmpty
        ? _defaultFinancialInstruction
        : financialInstruction.trim();
    final fitness = fitnessGoal.trim().isEmpty
        ? _defaultFitnessGoal
        : fitnessGoal.trim();
    final lifestyle = householdLifestyle.trim().isEmpty
        ? _defaultHouseholdLifestyle
        : householdLifestyle.trim();
    final decision = decisionSupportRule.trim().isEmpty
        ? _defaultDecisionSupportRule
        : decisionSupportRule.trim();

    return '''
$identity

$tone

CORE CONTEXT & BASELINES:

- Profession & Schedule: $profession

- Financials: Monthly income is $income BDT. $financial

- Fitness: $fitness

- Household & Lifestyle: $lifestyle

- Decision Support: $decision''';
  }

  /// User prompt for progress review (checklist vs current-month data).
  String composeProgressTemplate() {
    final income = monthlyIncomeBdt.trim().isEmpty
        ? _defaultMonthlyIncomeBdt
        : monthlyIncomeBdt.trim();
    final rules = PromptTemplateSections.rulesForProgressReview
        .replaceAll('{{monthlyIncomeBdt}}', income);
    final parts = <String>[
      rules,
      PromptTemplateSections.focusHeader,
      PromptTemplateSections.progressFocusDefault,
      PromptTemplateSections.dataForProgressReview,
      PromptTemplateSections.outputFormatProgressReview,
    ];
    return parts.join('\n\n');
  }

  /// User prompt payload sent to the model.
  String composeTemplate() {
    final income = monthlyIncomeBdt.trim().isEmpty
        ? _defaultMonthlyIncomeBdt
        : monthlyIncomeBdt.trim();
    final rules = PromptTemplateSections.rulesForAnalysis
        .replaceAll('{{monthlyIncomeBdt}}', income);
    final parts = <String>[
      rules,
      PromptTemplateSections.focusHeader,
      '{{focus}}',
      PromptTemplateSections.dataToAnalyze,
      PromptTemplateSections.outputFormat,
    ];
    // Runtime placeholders (avgSteps, week ranges, data blocks) are filled in
    // analysis_service.dart when a run starts — do not substitute them here.
    return parts.join('\n\n');
  }

  factory PromptConfig.initial() {
    return const PromptConfig(
      assistantIdentity: _defaultAssistantIdentity,
      toneInstruction: _defaultToneInstruction,
      professionAndSchedule: _defaultProfessionAndSchedule,
      monthlyIncomeBdt: _defaultMonthlyIncomeBdt,
      financialInstruction: _defaultFinancialInstruction,
      fitnessGoal: _defaultFitnessGoal,
      householdLifestyle: _defaultHouseholdLifestyle,
      decisionSupportRule: _defaultDecisionSupportRule,
      focus:
          'Analyze the specific anomalies listed below to identify high-impact patterns, '
          'then build a full {{checklistMonth}} checklist with one weekly segment for every week listed under Clear Next Actions (all five domains per week).',
    );
  }

  PromptConfig copyWith({
    String? assistantIdentity,
    String? toneInstruction,
    String? professionAndSchedule,
    String? monthlyIncomeBdt,
    String? financialInstruction,
    String? fitnessGoal,
    String? householdLifestyle,
    String? decisionSupportRule,
    String? focus,
  }) {
    return PromptConfig(
      assistantIdentity: assistantIdentity ?? this.assistantIdentity,
      toneInstruction: toneInstruction ?? this.toneInstruction,
      professionAndSchedule:
          professionAndSchedule ?? this.professionAndSchedule,
      monthlyIncomeBdt: monthlyIncomeBdt ?? this.monthlyIncomeBdt,
      financialInstruction: financialInstruction ?? this.financialInstruction,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      householdLifestyle: householdLifestyle ?? this.householdLifestyle,
      decisionSupportRule: decisionSupportRule ?? this.decisionSupportRule,
      focus: focus ?? this.focus,
    );
  }

  Map<String, dynamic> toJson() => {
    'assistantIdentity': assistantIdentity,
    'toneInstruction': toneInstruction,
    'professionAndSchedule': professionAndSchedule,
    'monthlyIncomeBdt': monthlyIncomeBdt,
    'financialInstruction': financialInstruction,
    'fitnessGoal': fitnessGoal,
    'householdLifestyle': householdLifestyle,
    'decisionSupportRule': decisionSupportRule,
    'focus': focus,
  };

  factory PromptConfig.fromJson(Map<String, dynamic> json) {
    return PromptConfig(
      assistantIdentity:
          json['assistantIdentity'] as String? ??
          PromptConfig.initial().assistantIdentity,
      toneInstruction:
          json['toneInstruction'] as String? ??
          PromptConfig.initial().toneInstruction,
      professionAndSchedule:
          json['professionAndSchedule'] as String? ??
          PromptConfig.initial().professionAndSchedule,
      monthlyIncomeBdt:
          json['monthlyIncomeBdt'] as String? ??
          PromptConfig.initial().monthlyIncomeBdt,
      financialInstruction:
          json['financialInstruction'] as String? ??
          PromptConfig.initial().financialInstruction,
      fitnessGoal:
          json['fitnessGoal'] as String? ?? PromptConfig.initial().fitnessGoal,
      householdLifestyle:
          json['householdLifestyle'] as String? ??
          PromptConfig.initial().householdLifestyle,
      decisionSupportRule:
          json['decisionSupportRule'] as String? ??
          PromptConfig.initial().decisionSupportRule,
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

    return PromptConfig.initial().copyWith(
      assistantIdentity: _extractLegacyIdentity(legacyTemplate),
      toneInstruction: _extractLegacyTone(legacyTemplate),
      focus: focus,
    );
  }
}

const _defaultAssistantIdentity =
    'You are a highly analytical, uncompromising personal data assistant for Rafid Rahman.';
const _defaultToneInstruction =
    'Balance empathy with strict candor. Do not sugarcoat poor metrics, excessive spending, or missed routines.';
const _defaultProfessionAndSchedule =
    'Software Engineer L1 (Flutter Developer) at Catch Bangladesh LTD. Work days are Sunday to Thursday, 10 AM to 6 PM.';
const _defaultMonthlyIncomeBdt = '80,000';
const _defaultFinancialInstruction =
    'Strict budget optimization is required. Provide exact fare breakdowns.';
const _defaultFitnessGoal =
    'The primary physical goal is maintaining a lean physique with visible abs. High baseline activity (NEAT) and adequate sleep are non-negotiable for recovery.';
const _defaultHouseholdLifestyle =
    'Married.  I live with family. Avoids social media. Enjoys making pizza at home and gaming.';
const _defaultDecisionSupportRule =
    'For any tech/electronics detected in expenses (e.g., relating to hardware like the Mac Mini, MSI Thin 15, Galaxy ecosystem, or mechanical keyboards), provide strict "Buy or Skip" analysis to validate if the price was fair.';

String _extractLegacyIdentity(String legacyTemplate) {
  final lines = legacyTemplate
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) return _defaultAssistantIdentity;
  return lines.first;
}

String _extractLegacyTone(String legacyTemplate) {
  final lines = legacyTemplate
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.length < 2) return _defaultToneInstruction;
  return lines[1];
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
