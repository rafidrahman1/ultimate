import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/weekday_schedule.dart';
import 'prompt_template_sections.dart';

const _promptConfigStorageKey = 'prompt_config_v2';
const _legacyPromptConfigStorageKey = 'prompt_config_v1';

enum EmploymentStatus { working, student, unemployed }

class PromptConfig {
  const PromptConfig({
    required this.assistantIdentity,
    required this.toneInstruction,
    required this.name,
    this.employmentStatus,
    required this.jobTitle,
    required this.employer,
    required this.weekendDays,
    required this.workHours,
    required this.schoolName,
    required this.studyProgram,
    required this.studyHours,
    required this.unemploymentSituation,
    required this.routineDays,
    required this.routineHours,
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
  final String name;
  final EmploymentStatus? employmentStatus;
  final String jobTitle;
  final String employer;
  final List<int> weekendDays;
  final String workHours;
  final String schoolName;
  final String studyProgram;
  final String studyHours;
  final String unemploymentSituation;
  final String routineDays;
  final String routineHours;
  final String monthlyIncomeBdt;
  final String financialInstruction;
  final String fitnessGoal;
  final String householdLifestyle;
  final String decisionSupportRule;
  final String focus;

  static const personalInfoFieldLabels = <String, String>{
    'name': 'Name',
    'employmentStatus': 'Employment status',
    'jobTitle': 'Job title',
    'employer': 'Employer',
    'weekendDays': 'Weekend days',
    'workHours': 'Work hours',
    'schoolName': 'School or university',
    'studyProgram': 'Program or major',
    'studyHours': 'Study hours',
    'unemploymentSituation': 'Current situation',
    'routineDays': 'Typical days',
    'routineHours': 'Typical hours',
    'monthlyIncomeBdt': 'Monthly income (BDT)',
    'financialInstruction': 'Financial rules',
    'fitnessGoal': 'Fitness goal',
    'householdLifestyle': 'Household and lifestyle',
    'decisionSupportRule': 'Decision support rule',
  };

  static const _sharedPersonalInfoKeys = [
    'financialInstruction',
    'fitnessGoal',
    'householdLifestyle',
    'decisionSupportRule',
  ];

  bool get requiresMonthlyIncome => employmentStatus == EmploymentStatus.working;

  String get analysisMonthlyIncomeBdt =>
      requiresMonthlyIncome ? monthlyIncomeBdt.trim() : '0';

  List<String> get requiredPersonalInfoKeys => [
    'name',
    'employmentStatus',
    ...switch (employmentStatus) {
      EmploymentStatus.working => const [
        'jobTitle',
        'employer',
        'weekendDays',
        'workHours',
        'monthlyIncomeBdt',
      ],
      EmploymentStatus.student => const [
        'schoolName',
        'studyProgram',
        'weekendDays',
        'studyHours',
      ],
      EmploymentStatus.unemployed => const [
        'unemploymentSituation',
        'routineDays',
        'routineHours',
      ],
      null => const <String>[],
    },
    ..._sharedPersonalInfoKeys,
  ];

  String get professionAndSchedule => composeProfessionAndSchedule();

  String composeAssistantIdentity() {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return _defaultAssistantIdentity;
    return 'You are a highly analytical, uncompromising personal data assistant for $trimmedName.';
  }

  String composeToneInstruction() {
    final trimmed = toneInstruction.trim();
    return trimmed.isEmpty ? _defaultToneInstruction : trimmed;
  }

  String composeProfessionAndSchedule() => switch (employmentStatus) {
    EmploymentStatus.working => _composeWorkingProfile(),
    EmploymentStatus.student => _composeStudentProfile(),
    EmploymentStatus.unemployed => _composeUnemployedProfile(),
    null => '',
  };

  String _composeWorkingProfile() {
    final title = jobTitle.trim();
    final company = employer.trim();
    final buffer = StringBuffer();
    if (title.isNotEmpty && company.isNotEmpty) {
      buffer.write('$title at $company');
    } else if (title.isNotEmpty) {
      buffer.write(title);
    } else if (company.isNotEmpty) {
      buffer.write(company);
    }
    _appendWeekendAndHours(
      buffer,
      hoursPrefix: 'Work hours are',
      hours: workHours.trim(),
    );
    return buffer.toString();
  }

  String _composeStudentProfile() {
    final school = schoolName.trim();
    final program = studyProgram.trim();
    final buffer = StringBuffer('Student');
    if (school.isNotEmpty && program.isNotEmpty) {
      buffer.write(' at $school studying $program');
    } else if (school.isNotEmpty) {
      buffer.write(' at $school');
    } else if (program.isNotEmpty) {
      buffer.write(' studying $program');
    }
    _appendWeekendAndHours(
      buffer,
      hoursPrefix: 'Study hours are',
      hours: studyHours.trim(),
    );
    return buffer.toString();
  }

  String _composeUnemployedProfile() {
    final situation = unemploymentSituation.trim();
    final buffer = StringBuffer('Currently unemployed');
    if (situation.isNotEmpty) {
      buffer.write(': $situation');
    }
    _appendScheduleSentence(
      buffer,
      prefix: 'Typical days are',
      days: routineDays.trim(),
      hours: routineHours.trim(),
    );
    return buffer.toString();
  }

  void _appendWeekendAndHours(
    StringBuffer buffer, {
    required String hoursPrefix,
    required String hours,
  }) {
    if (weekendDays.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('. ');
      buffer.write('Weekend days are ${formatWeekdayList(weekendDays)}');
    }
    if (hours.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('. ');
      buffer.write('$hoursPrefix $hours');
    }
  }

  void _appendScheduleSentence(
    StringBuffer buffer, {
    required String prefix,
    required String days,
    required String hours,
  }) {
    if (days.isEmpty && hours.isEmpty) return;
    if (buffer.isNotEmpty) buffer.write('. ');
    buffer.write(prefix);
    buffer.write(' ');
    if (days.isNotEmpty && hours.isNotEmpty) {
      buffer.write('$days, $hours');
    } else if (days.isNotEmpty) {
      buffer.write(days);
    } else {
      buffer.write(hours);
    }
  }

  bool get isPersonalInfoComplete =>
      requiredPersonalInfoKeys.every(_isPersonalInfoValuePresent);

  List<String> get missingPersonalInfoLabels {
    final missing = <String>[];
    for (final key in requiredPersonalInfoKeys) {
      if (!_isPersonalInfoValuePresent(key)) {
        missing.add(personalInfoFieldLabels[key]!);
      }
    }
    return missing;
  }

  bool _isPersonalInfoValuePresent(String key) {
    if (key == 'weekendDays') return weekendDays.isNotEmpty;
    return _personalInfoValueForKey(key).trim().isNotEmpty;
  }

  String _personalInfoValueForKey(String key) => switch (key) {
    'name' => name,
    'employmentStatus' => employmentStatus?.name ?? '',
    'jobTitle' => jobTitle,
    'employer' => employer,
    'weekendDays' => weekendDays.isEmpty ? '' : 'set',
    'workHours' => workHours,
    'schoolName' => schoolName,
    'studyProgram' => studyProgram,
    'studyHours' => studyHours,
    'unemploymentSituation' => unemploymentSituation,
    'routineDays' => routineDays,
    'routineHours' => routineHours,
    'monthlyIncomeBdt' => monthlyIncomeBdt,
    'financialInstruction' => financialInstruction,
    'fitnessGoal' => fitnessGoal,
    'householdLifestyle' => householdLifestyle,
    'decisionSupportRule' => decisionSupportRule,
    _ => '',
  };

  /// System instruction sent with each API request.
  String composeSystemInstruction() {
    final identity = composeAssistantIdentity();
    final tone = composeToneInstruction();
    final profession = composeProfessionAndSchedule();
    final financial = financialInstruction.trim();
    final fitness = fitnessGoal.trim();
    final lifestyle = householdLifestyle.trim();
    final decision = decisionSupportRule.trim();
    final financialsLine = requiresMonthlyIncome
        ? '- Financials: Monthly income is ${monthlyIncomeBdt.trim()} BDT. $financial'
        : '- Financials: No salary income reported. $financial';

    return '''
$identity

$tone

CORE CONTEXT & BASELINES:

- Name: ${name.trim()}

- Profession & Schedule: $profession

$financialsLine

- Fitness: $fitness

- Household & Lifestyle: $lifestyle

- Decision Support: $decision''';
  }

  /// User prompt for progress review (checklist vs current-month data).
  String composeProgressTemplate() {
    final income = analysisMonthlyIncomeBdt;
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
    final income = analysisMonthlyIncomeBdt;
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
      name: '',
      employmentStatus: null,
      jobTitle: '',
      employer: '',
      weekendDays: const [],
      workHours: '',
      schoolName: '',
      studyProgram: '',
      studyHours: '',
      unemploymentSituation: '',
      routineDays: '',
      routineHours: '',
      monthlyIncomeBdt: '',
      financialInstruction: '',
      fitnessGoal: '',
      householdLifestyle: '',
      decisionSupportRule: '',
      focus:
          'Analyze the specific anomalies listed below to identify high-impact patterns, '
          'then build a full {{checklistMonth}} checklist with one weekly segment for every week listed under Clear Next Actions (all five domains per week).',
    );
  }

  PromptConfig copyWith({
    String? assistantIdentity,
    String? toneInstruction,
    String? name,
    EmploymentStatus? employmentStatus,
    bool clearEmploymentStatus = false,
    String? jobTitle,
    String? employer,
    List<int>? weekendDays,
    String? workHours,
    String? schoolName,
    String? studyProgram,
    String? studyHours,
    String? unemploymentSituation,
    String? routineDays,
    String? routineHours,
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
      name: name ?? this.name,
      employmentStatus: clearEmploymentStatus
          ? null
          : (employmentStatus ?? this.employmentStatus),
      jobTitle: jobTitle ?? this.jobTitle,
      employer: employer ?? this.employer,
      weekendDays: weekendDays ?? this.weekendDays,
      workHours: workHours ?? this.workHours,
      schoolName: schoolName ?? this.schoolName,
      studyProgram: studyProgram ?? this.studyProgram,
      studyHours: studyHours ?? this.studyHours,
      unemploymentSituation:
          unemploymentSituation ?? this.unemploymentSituation,
      routineDays: routineDays ?? this.routineDays,
      routineHours: routineHours ?? this.routineHours,
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
    'name': name,
    if (employmentStatus != null) 'employmentStatus': employmentStatus!.name,
    'jobTitle': jobTitle,
    'employer': employer,
    'weekendDays': weekendDays,
    'workHours': workHours,
    'schoolName': schoolName,
    'studyProgram': studyProgram,
    'studyHours': studyHours,
    'unemploymentSituation': unemploymentSituation,
    'routineDays': routineDays,
    'routineHours': routineHours,
    'monthlyIncomeBdt': monthlyIncomeBdt,
    'financialInstruction': financialInstruction,
    'fitnessGoal': fitnessGoal,
    'householdLifestyle': householdLifestyle,
    'decisionSupportRule': decisionSupportRule,
    'focus': focus,
  };

  factory PromptConfig.fromJson(Map<String, dynamic> json) {
    final legacyProfession = json['professionAndSchedule'] as String? ?? '';
    var jobTitle = json['jobTitle'] as String? ?? '';
    var employer = json['employer'] as String? ?? '';
    final workHours = json['workHours'] as String? ?? '';
    final weekendDays = parseWeekendDaysFromJson(json['weekendDays']);

    if (jobTitle.isEmpty &&
        employer.isEmpty &&
        weekendDays.isEmpty &&
        workHours.isEmpty &&
        legacyProfession.isNotEmpty) {
      jobTitle = legacyProfession;
    }

    var employmentStatus = _employmentStatusFromJson(
      json['employmentStatus'] as String?,
    );
    if (employmentStatus == null &&
        (jobTitle.isNotEmpty ||
            employer.isNotEmpty ||
            weekendDays.isNotEmpty ||
            workHours.isNotEmpty)) {
      employmentStatus = EmploymentStatus.working;
    }

    return PromptConfig(
      assistantIdentity:
          json['assistantIdentity'] as String? ??
          PromptConfig.initial().assistantIdentity,
      toneInstruction:
          json['toneInstruction'] as String? ??
          PromptConfig.initial().toneInstruction,
      name: json['name'] as String? ?? '',
      employmentStatus: employmentStatus,
      jobTitle: jobTitle,
      employer: employer,
      weekendDays: weekendDays,
      workHours: workHours,
      schoolName: json['schoolName'] as String? ?? '',
      studyProgram: json['studyProgram'] as String? ?? '',
      studyHours: json['studyHours'] as String? ?? '',
      unemploymentSituation: json['unemploymentSituation'] as String? ?? '',
      routineDays: json['routineDays'] as String? ?? '',
      routineHours: json['routineHours'] as String? ?? '',
      monthlyIncomeBdt: json['monthlyIncomeBdt'] as String? ?? '',
      financialInstruction: json['financialInstruction'] as String? ?? '',
      fitnessGoal: json['fitnessGoal'] as String? ?? '',
      householdLifestyle: json['householdLifestyle'] as String? ?? '',
      decisionSupportRule: json['decisionSupportRule'] as String? ?? '',
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
    'You are a highly analytical, uncompromising personal data assistant.';
const _defaultToneInstruction =
    'Balance empathy with strict candor. Do not sugarcoat poor metrics, excessive spending, or missed routines.';

const missingPersonalInfoMessage =
    'Complete your personal information before running analysis.';

EmploymentStatus? _employmentStatusFromJson(String? raw) {
  if (raw == null) return null;
  for (final status in EmploymentStatus.values) {
    if (status.name == raw) return status;
  }
  return null;
}

String _extractLegacyIdentity(String legacyTemplate) {
  final lines = legacyTemplate
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) return PromptConfig.initial().assistantIdentity;
  return lines.first;
}

String _extractLegacyTone(String legacyTemplate) {
  final lines = legacyTemplate
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.length < 2) return PromptConfig.initial().toneInstruction;
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
