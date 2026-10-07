part of 'prompt_config_service.dart';

/// Builds the prompt text (identity, tone, profile, templates) from a [PromptConfig].
extension PromptConfigComposition on PromptConfig {
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

  String composePersonalDetailsBlock() {
    final lines = <String>[
      '- Name: ${name.trim()}',
      if (age.trim().isNotEmpty) '- Age: ${age.trim()}',
      if (gender.trim().isNotEmpty) '- Gender: ${gender.trim()}',
      if (location.trim().isNotEmpty) '- Location: ${location.trim()}',
      if (maritalStatus.trim().isNotEmpty)
        '- Marital status: ${maritalStatus.trim()}',
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
    'monthlyBudgetBdt' => monthlyBudgetBdt,
    'financialInstruction' => financialInstruction,
    'fitnessGoal' => fitnessGoal,
    'householdLifestyle' => householdLifestyle,
    'ride' => ride,
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
    final rideText = ride.trim();
    final decision = decisionSupportRule.trim();
    final budget = monthlyBudgetBdt.trim();
    final incomeLine = requiresMonthlyIncome
        ? 'Monthly income is ${monthlyIncomeBdt.trim()} BDT'
        : 'No salary income reported';
    final budgetLine = budget.isNotEmpty
        ? '. Monthly budget is $budget BDT'
        : '';
    final financialsLine = '- Financials: $incomeLine$budgetLine. $financial';

    return '''
$identity

$tone

CORE CONTEXT & BASELINES:

${composePersonalDetailsBlock()}

- Profession & Schedule: $profession

$financialsLine

- Fitness: $fitness

- Household & Lifestyle: $lifestyle${rideText.isEmpty ? '' : '\n\n- Ride: $rideText'}

- Decision Support: $decision''';
  }

  /// User prompt for progress review (checklist vs current-month data).
  String composeProgressTemplate() {
    final income = analysisMonthlyIncomeBdt;
    final rules = PromptTemplateSections.rulesForProgressReview.replaceAll(
      '{{monthlyIncomeBdt}}',
      income,
    );
    final parts = <String>[
      rules,
      PromptTemplateSections.focusHeader,
      PromptTemplateSections.progressFocusDefault,
      PromptTemplateSections.dataForProgressReview,
      PromptTemplateSections.outputFormatProgressReview,
    ];
    return parts.join('\n\n');
  }

  /// User prompt for weekly checklist verification (one week vs week data).
  String composeWeeklyVerifyTemplate() {
    final income = analysisMonthlyIncomeBdt;
    final rules = PromptTemplateSections.rulesForWeeklyChecklistVerification
        .replaceAll('{{monthlyIncomeBdt}}', income);
    final parts = <String>[
      rules,
      PromptTemplateSections.focusHeader,
      PromptTemplateSections.weeklyVerifyFocusDefault,
      PromptTemplateSections.dataForWeeklyChecklistVerification,
      PromptTemplateSections.outputFormatWeeklyChecklistVerification,
    ];
    return parts.join('\n\n');
  }

  /// User prompt payload sent to the model.
  String composeTemplate() {
    final parts = <String>[
      PromptTemplateSections.internalAnalysisPipeline,
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
}
