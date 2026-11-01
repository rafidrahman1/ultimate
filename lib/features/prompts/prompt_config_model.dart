part of 'prompt_config_service.dart';

// PromptConfig model: personal-profile fields and JSON (de)serialization.

enum EmploymentStatus { working, student, unemployed }

class PromptConfig {
  const PromptConfig({
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
    required this.monthlyBudgetBdt,
    required this.financialInstruction,
    required this.fitnessGoal,
    required this.householdLifestyle,
    this.ride = '',
    required this.decisionSupportRule,
  });

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
  final String monthlyBudgetBdt;
  final String financialInstruction;
  final String fitnessGoal;
  final String householdLifestyle;

  /// The user's bike or car, e.g. "Vespa Primavera 150". Optional.
  final String ride;
  final String decisionSupportRule;

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
    'monthlyBudgetBdt': 'Monthly budget (BDT)',
    'financialInstruction': 'Financial rules',
    'fitnessGoal': 'Fitness goal',
    'householdLifestyle': 'Household and lifestyle',
    'ride': 'Your ride',
    'decisionSupportRule': 'Decision support rule',
  };

  static const _sharedPersonalInfoKeys = [
    'financialInstruction',
    'fitnessGoal',
    'householdLifestyle',
    'decisionSupportRule',
  ];

  bool get requiresMonthlyIncome =>
      employmentStatus == EmploymentStatus.working;

  String get analysisMonthlyIncomeBdt =>
      requiresMonthlyIncome ? monthlyIncomeBdt.trim() : '0';

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

  factory PromptConfig.initial() {
    return PromptConfig(
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
      monthlyBudgetBdt: '',
      financialInstruction: '',
      fitnessGoal: '',
      householdLifestyle: '',
      decisionSupportRule: '',
    );
  }

  PromptConfig copyWith({
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
    String? monthlyBudgetBdt,
    String? financialInstruction,
    String? fitnessGoal,
    String? householdLifestyle,
    String? ride,
    String? decisionSupportRule,
  }) {
    return PromptConfig(
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
      monthlyBudgetBdt: monthlyBudgetBdt ?? this.monthlyBudgetBdt,
      financialInstruction: financialInstruction ?? this.financialInstruction,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      householdLifestyle: householdLifestyle ?? this.householdLifestyle,
      ride: ride ?? this.ride,
      decisionSupportRule: decisionSupportRule ?? this.decisionSupportRule,
    );
  }

  Map<String, dynamic> toPersonalInfoJson() {
    return toJson();
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
      monthlyBudgetBdt: parsed.monthlyBudgetBdt,
      financialInstruction: parsed.financialInstruction,
      fitnessGoal: parsed.fitnessGoal,
      householdLifestyle: parsed.householdLifestyle,
      ride: parsed.ride,
      decisionSupportRule: parsed.decisionSupportRule,
    );
  }

  bool get hasAnyPersonalInfo => toPersonalInfoJson().values.any((value) {
    if (value is List<int>) return value.isNotEmpty;
    if (value is String) return value.trim().isNotEmpty;
    return value != null;
  });

  Map<String, dynamic> toJson() => {
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
    'monthlyBudgetBdt': monthlyBudgetBdt,
    'financialInstruction': financialInstruction,
    'fitnessGoal': fitnessGoal,
    'householdLifestyle': householdLifestyle,
    'ride': ride,
    'decisionSupportRule': decisionSupportRule,
  };

  factory PromptConfig.fromJson(Map<String, dynamic> json) {
    final legacyProfession = json['professionAndSchedule'] as String? ?? '';
    var jobTitle = json['jobTitle'] as String? ?? '';
    final employer = json['employer'] as String? ?? '';
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
      monthlyBudgetBdt: json['monthlyBudgetBdt'] as String? ?? '',
      financialInstruction: json['financialInstruction'] as String? ?? '',
      fitnessGoal: json['fitnessGoal'] as String? ?? '',
      householdLifestyle: json['householdLifestyle'] as String? ?? '',
      ride: json['ride'] as String? ?? '',
      decisionSupportRule: json['decisionSupportRule'] as String? ?? '',
    );
  }
}

EmploymentStatus? _employmentStatusFromJson(String? raw) {
  if (raw == null) return null;
  for (final status in EmploymentStatus.values) {
    if (status.name == raw) return status;
  }
  return null;
}
