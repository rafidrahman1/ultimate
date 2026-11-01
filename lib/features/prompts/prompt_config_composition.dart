part of 'prompt_config_service.dart';

/// Completeness checks for the personal profile in a [PromptConfig].
extension PromptConfigComposition on PromptConfig {
  bool get isPersonalInfoComplete =>
      requiredPersonalInfoKeys.every(_isPersonalInfoValuePresent);

  List<String> get missingPersonalInfoKeys => [
    for (final key in requiredPersonalInfoKeys)
      if (!_isPersonalInfoValuePresent(key)) key,
  ];

  List<String> get missingPersonalInfoLabels {
    final missing = <String>[];
    for (final key in requiredPersonalInfoKeys) {
      if (!_isPersonalInfoValuePresent(key)) {
        missing.add(PromptConfig.personalInfoFieldLabels[key]!);
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
    'monthlyBudgetBdt' => monthlyBudgetBdt,
    'financialInstruction' => financialInstruction,
    'fitnessGoal' => fitnessGoal,
    'householdLifestyle' => householdLifestyle,
    'ride' => ride,
    'decisionSupportRule' => decisionSupportRule,
    _ => '',
  };
}
