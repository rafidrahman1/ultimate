import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/core/weekday_schedule.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/prompts/personal_info_firestore_service.dart';
import 'package:personal/features/prompts/prompt_template_sections.dart';

const _promptConfigStorageKey = 'prompt_config_v2';
const _legacyPromptConfigStorageKey = 'prompt_config_v1';
const _personalInfoLocalUpdatedAtKey = 'personal_info_local_updated_at_ms';

enum EmploymentStatus { working, student, unemployed }

class PromptConfig {
  const PromptConfig({
    required this.assistantIdentity,
    required this.toneInstruction,
    required this.name,
    required this.age,
    required this.gender,
    required this.location,
    required this.maritalStatus,
    this.employmentStatus,
    required this.jobTitle,
    required this.employer,
    required this.workAddress,
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
    required this.crossDomainImpacts,
    required this.customCrossDomainImpacts,
    required this.focus,
  });

  /// Editable system prompt fields.
  final String assistantIdentity;
  final String toneInstruction;
  final String name;
  final String age;
  final String gender;
  final String location;
  final String maritalStatus;
  final EmploymentStatus? employmentStatus;
  final String jobTitle;
  final String employer;
  final String workAddress;
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
  final List<String> crossDomainImpacts;
  final List<String> customCrossDomainImpacts;
  final String focus;

  static const personalInfoFieldLabels = <String, String>{
    'name': 'Name',
    'age': 'Age',
    'gender': 'Gender',
    'location': 'Location',
    'maritalStatus': 'Marital status',
    'employmentStatus': 'Employment status',
    'jobTitle': 'Job title',
    'employer': 'Employer',
    'workAddress': 'Work address',
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

  List<String> get effectiveCrossDomainImpacts => crossDomainImpacts.isEmpty
      ? List<String>.from(PromptTemplateSections.defaultCrossDomainImpacts)
      : crossDomainImpacts;

  String composeCrossDomainImpactsBlock() {
    return effectiveCrossDomainImpacts.map((item) => '* $item').join('\n');
  }

  String composeRulesForAnalysis() {
    return PromptTemplateSections.rulesForAnalysis
        .replaceAll('{{monthlyIncomeBdt}}', analysisMonthlyIncomeBdt)
        .replaceAll(
          '{{crossDomainImpacts}}',
          composeCrossDomainImpactsBlock(),
        );
  }

  static const basicPersonalInfoKeys = [
    'name',
    'age',
    'gender',
    'location',
    'maritalStatus',
  ];

  List<String> get requiredPersonalInfoKeys => [
    ...basicPersonalInfoKeys,
    'employmentStatus',
    ...switch (employmentStatus) {
      EmploymentStatus.working => const [
        'jobTitle',
        'employer',
        'workAddress',
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
    final address = workAddress.trim();
    final buffer = StringBuffer();
    if (title.isNotEmpty && company.isNotEmpty) {
      buffer.write('$title at $company');
    } else if (title.isNotEmpty) {
      buffer.write(title);
    } else if (company.isNotEmpty) {
      buffer.write(company);
    }
    if (address.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('. ');
      buffer.write('Work address: $address');
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

  String composePersonalDetailsBlock() {
    final lines = <String>[
      '- Name: ${name.trim()}',
      if (age.trim().isNotEmpty) '- Age: ${age.trim()}',
      if (gender.trim().isNotEmpty) '- Gender: ${gender.trim()}',
      if (location.trim().isNotEmpty) '- Location: ${location.trim()}',
      if (maritalStatus.trim().isNotEmpty) '- Marital status: ${maritalStatus.trim()}',
    ];
    return lines.join('\n\n');
  }

  String _personalInfoValueForKey(String key) => switch (key) {
    'name' => name,
    'age' => age,
    'gender' => gender,
    'location' => location,
    'maritalStatus' => maritalStatus,
    'employmentStatus' => employmentStatus?.name ?? '',
    'jobTitle' => jobTitle,
    'employer' => employer,
    'workAddress' => workAddress,
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

${composePersonalDetailsBlock()}

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
    final parts = <String>[
      composeRulesForAnalysis(),
      PromptTemplateSections.focusHeader,
      '{{focus}}',
      PromptTemplateSections.derivedMetrics,
      PromptTemplateSections.dataToAnalyze,
      PromptTemplateSections.outputFormat,
    ];
    // Runtime placeholders (expenseCategories, week ranges, data blocks) are
    // filled in analysis_service.dart when a run starts — do not substitute
    // them here. crossDomainImpacts is filled from personal info.
    return parts.join('\n\n');
  }

  factory PromptConfig.initial() {
    return PromptConfig(
      assistantIdentity: _defaultAssistantIdentity,
      toneInstruction: _defaultToneInstruction,
      name: '',
      age: '',
      gender: '',
      location: '',
      maritalStatus: '',
      employmentStatus: null,
      jobTitle: '',
      employer: '',
      workAddress: '',
      weekendDays: [],
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
      crossDomainImpacts: List<String>.from(
        PromptTemplateSections.defaultCrossDomainImpacts,
      ),
      customCrossDomainImpacts: const [],
      focus:
          'Analyze the specific anomalies listed below to identify high-impact patterns, '
          'then build a full {{checklistMonth}} checklist with one weekly segment for every week listed under Clear Next Actions (include only domains present in DATA TO ANALYZE).',
    );
  }

  PromptConfig copyWith({
    String? assistantIdentity,
    String? toneInstruction,
    String? name,
    String? age,
    String? gender,
    String? location,
    String? maritalStatus,
    EmploymentStatus? employmentStatus,
    bool clearEmploymentStatus = false,
    String? jobTitle,
    String? employer,
    String? workAddress,
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
    List<String>? crossDomainImpacts,
    List<String>? customCrossDomainImpacts,
    String? focus,
  }) {
    return PromptConfig(
      assistantIdentity: assistantIdentity ?? this.assistantIdentity,
      toneInstruction: toneInstruction ?? this.toneInstruction,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      location: location ?? this.location,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      employmentStatus: clearEmploymentStatus
          ? null
          : (employmentStatus ?? this.employmentStatus),
      jobTitle: jobTitle ?? this.jobTitle,
      employer: employer ?? this.employer,
      workAddress: workAddress ?? this.workAddress,
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
      crossDomainImpacts: crossDomainImpacts ?? this.crossDomainImpacts,
      customCrossDomainImpacts:
          customCrossDomainImpacts ?? this.customCrossDomainImpacts,
      focus: focus ?? this.focus,
    );
  }

  Map<String, dynamic> toPersonalInfoJson() {
    final json = toJson();
    json
      ..remove('assistantIdentity')
      ..remove('toneInstruction')
      ..remove('focus');
    return json;
  }

  PromptConfig mergePersonalInfo(Map<String, dynamic> cloud) {
    final filtered = Map<String, dynamic>.from(cloud)..remove('updatedAt');
    final parsed = PromptConfig.fromJson({...toJson(), ...filtered});
    return copyWith(
      name: parsed.name,
      age: parsed.age,
      gender: parsed.gender,
      location: parsed.location,
      maritalStatus: parsed.maritalStatus,
      employmentStatus: parsed.employmentStatus,
      clearEmploymentStatus: parsed.employmentStatus == null,
      jobTitle: parsed.jobTitle,
      employer: parsed.employer,
      workAddress: parsed.workAddress,
      weekendDays: parsed.weekendDays,
      workHours: parsed.workHours,
      schoolName: parsed.schoolName,
      studyProgram: parsed.studyProgram,
      studyHours: parsed.studyHours,
      unemploymentSituation: parsed.unemploymentSituation,
      routineDays: parsed.routineDays,
      routineHours: parsed.routineHours,
      monthlyIncomeBdt: parsed.monthlyIncomeBdt,
      financialInstruction: parsed.financialInstruction,
      fitnessGoal: parsed.fitnessGoal,
      householdLifestyle: parsed.householdLifestyle,
      decisionSupportRule: parsed.decisionSupportRule,
      crossDomainImpacts: parsed.crossDomainImpacts,
      customCrossDomainImpacts: parsed.customCrossDomainImpacts,
    );
  }

  bool get hasAnyPersonalInfo =>
      toPersonalInfoJson().values.any((value) {
        if (value is List<int>) return value.isNotEmpty;
        if (value is String) return value.trim().isNotEmpty;
        return value != null;
      });

  Map<String, dynamic> toJson() => {
    'assistantIdentity': assistantIdentity,
    'toneInstruction': toneInstruction,
    'name': name,
    'age': age,
    'gender': gender,
    'location': location,
    'maritalStatus': maritalStatus,
    if (employmentStatus != null) 'employmentStatus': employmentStatus!.name,
    'jobTitle': jobTitle,
    'employer': employer,
    'workAddress': workAddress,
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
    'crossDomainImpacts': crossDomainImpacts,
    'customCrossDomainImpacts': customCrossDomainImpacts,
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
      age: json['age'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      location: json['location'] as String? ?? '',
      maritalStatus: json['maritalStatus'] as String? ?? '',
      employmentStatus: employmentStatus,
      jobTitle: jobTitle,
      employer: employer,
      workAddress: json['workAddress'] as String? ?? '',
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
      crossDomainImpacts: _preferenceMetricsFromJson(
        json['crossDomainImpacts'],
        PromptTemplateSections.defaultCrossDomainImpacts,
      ),
      customCrossDomainImpacts: _customPreferenceMetricsFromJson(
        json,
        enabledKey: 'crossDomainImpacts',
        customKey: 'customCrossDomainImpacts',
        defaults: PromptTemplateSections.defaultCrossDomainImpacts,
      ),
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

List<String> _stringListFromJson(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

List<String> _preferenceMetricsFromJson(
  Object? raw,
  List<String> defaults,
) {
  if (raw is! List) {
    return List<String>.from(defaults);
  }
  return _stringListFromJson(raw);
}

List<String> _customPreferenceMetricsFromJson(
  Map<String, dynamic> json, {
  required String enabledKey,
  required String customKey,
  required List<String> defaults,
}) {
  final stored = _stringListFromJson(json[customKey]);
  if (stored.isNotEmpty) return stored;

  return _preferenceMetricsFromJson(json[enabledKey], defaults)
      .where((item) => !defaults.contains(item))
      .toList();
}

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

class PromptConfigSaveResult {
  const PromptConfigSaveResult({
    required this.savedLocally,
    this.syncedToCloud = false,
    this.syncError,
  });

  final bool savedLocally;
  final bool syncedToCloud;
  final String? syncError;
}

class PersonalInfoSyncResult {
  const PersonalInfoSyncResult({
    this.synced = false,
    this.noCloudData = false,
    this.notSignedIn = false,
    this.error,
  });

  final bool synced;
  final bool noCloudData;
  final bool notSignedIn;
  final String? error;
}

final promptConfigProvider =
    AsyncNotifierProvider<PromptConfigNotifier, PromptConfig>(
      PromptConfigNotifier.new,
    );

class PromptConfigNotifier extends AsyncNotifier<PromptConfig> {
  @override
  Future<PromptConfig> build() async {
    final local = await _loadLocal();
    return _syncFromCloudIfNeeded(local);
  }

  Future<PromptConfig> _loadLocal() async {
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

  Future<void> _saveLocal(PromptConfig next, {DateTime? updatedAt}) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_promptConfigStorageKey, jsonEncode(next.toJson()));
    await prefs.setInt(
      _personalInfoLocalUpdatedAtKey,
      (updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  DateTime? _readLocalUpdatedAt(SharedPreferences prefs) {
    final millis = prefs.getInt(_personalInfoLocalUpdatedAtKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<PromptConfig> _syncFromCloudIfNeeded(PromptConfig local) async {
    final auth = ref.read(googleAccountServiceProvider);
    final user = auth.currentUser;
    if (user == null) return local;

    try {
      final firestore = ref.read(personalInfoFirestoreServiceProvider);
      final cloud = await firestore.loadPersonalInfo(user.uid);
      if (cloud == null) {
        if (local.hasAnyPersonalInfo) {
          await firestore.savePersonalInfo(user.uid, local);
        }
        return local;
      }

      final prefs = await SharedPreferences.getInstance();
      final localUpdatedAt = _readLocalUpdatedAt(prefs);
      final cloudUpdatedAt = cloud.updatedAt;

      if (cloudUpdatedAt != null &&
          (localUpdatedAt == null || cloudUpdatedAt.isAfter(localUpdatedAt))) {
        final merged = local.mergePersonalInfo(cloud.data);
        await _saveLocal(merged, updatedAt: cloudUpdatedAt);
        return merged;
      }

      return local;
    } catch (_) {
      return local;
    }
  }

  Future<void> syncFromCloud() async {
    final current = state.valueOrNull ?? await _loadLocal();
    final synced = await _syncFromCloudIfNeeded(current);
    if (synced != current) {
      state = AsyncData(synced);
    }
  }

  Future<PersonalInfoSyncResult> pullPersonalInfoFromCloud() async {
    final auth = ref.read(googleAccountServiceProvider);
    final user = auth.currentUser;
    if (user == null) {
      return const PersonalInfoSyncResult(notSignedIn: true);
    }

    try {
      final firestore = ref.read(personalInfoFirestoreServiceProvider);
      final current = state.valueOrNull ?? await _loadLocal();
      final cloud = await firestore.loadPersonalInfo(user.uid);
      if (cloud == null) {
        return const PersonalInfoSyncResult(noCloudData: true);
      }

      final merged = current.mergePersonalInfo(cloud.data);
      await _saveLocal(merged, updatedAt: cloud.updatedAt);
      return const PersonalInfoSyncResult(synced: true);
    } catch (error) {
      return PersonalInfoSyncResult(error: error.toString());
    }
  }

  Future<PromptConfigSaveResult> save(
    PromptConfig next, {
    bool syncToCloud = true,
  }) async {
    await _saveLocal(next);

    if (!syncToCloud) {
      return const PromptConfigSaveResult(savedLocally: true);
    }

    final auth = ref.read(googleAccountServiceProvider);
    final user = auth.currentUser;
    if (user == null) {
      return const PromptConfigSaveResult(savedLocally: true);
    }

    try {
      final firestore = ref.read(personalInfoFirestoreServiceProvider);
      final cloudUpdatedAt = await firestore.savePersonalInfo(user.uid, next);
      if (cloudUpdatedAt != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          _personalInfoLocalUpdatedAtKey,
          cloudUpdatedAt.millisecondsSinceEpoch,
        );
      }
      return const PromptConfigSaveResult(
        savedLocally: true,
        syncedToCloud: true,
      );
    } catch (error) {
      return PromptConfigSaveResult(
        savedLocally: true,
        syncError: error.toString(),
      );
    }
  }

  Future<void> reset({bool syncToCloud = true}) =>
      save(PromptConfig.initial(), syncToCloud: syncToCloud);
}
