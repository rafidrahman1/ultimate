import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/prompts/prompt_template_sections.dart';

PromptConfig _samplePersonalConfig() {
  return PromptConfig.initial().copyWith(
    name: 'Alex Morgan',
    age: '28',
    gender: 'Male',
    location: 'Dhaka, Bangladesh',
    maritalStatus: 'Married',
    employmentStatus: EmploymentStatus.working,
    jobTitle: 'Software Engineer',
    employer: 'Acme Corp',
    workAddress: '123 Main Road, Gulshan, Dhaka',
    weekendDays: const [DateTime.friday, DateTime.saturday],
    workHours: '10 AM to 6 PM',
    monthlyIncomeBdt: '80,000',
    financialInstruction: 'Strict budget optimization.',
    fitnessGoal: 'Maintain lean physique.',
    householdLifestyle: 'Lives with family.',
    decisionSupportRule: 'Provide Buy or Skip for electronics.',
  );
}

void main() {
  test('initial personal information fields are empty', () {
    final config = PromptConfig.initial();

    expect(config.weekendDays, isEmpty);
    expect(config.professionAndSchedule, isEmpty);
    expect(config.monthlyIncomeBdt, isEmpty);
    expect(config.employmentStatus, isNull);
    expect(config.isPersonalInfoComplete, isFalse);
    expect(config.name, isEmpty);
    expect(config.missingPersonalInfoLabels, hasLength(10));
    expect(config.missingPersonalInfoLabels, contains('Name'));
    expect(config.missingPersonalInfoLabels, contains('Age'));
    expect(config.missingPersonalInfoLabels, contains('Gender'));
    expect(config.missingPersonalInfoLabels, contains('Location'));
    expect(config.missingPersonalInfoLabels, contains('Marital status'));
    expect(config.missingPersonalInfoLabels, contains('Employment status'));
    expect(config.missingPersonalInfoLabels, isNot(contains('Monthly income (BDT)')));
  });

  test('isPersonalInfoComplete requires every personal field', () {
    final partial = PromptConfig.initial().copyWith(
      name: 'Jamie',
      age: '30',
      gender: 'Female',
      location: 'Chittagong',
      maritalStatus: 'Single',
      employmentStatus: EmploymentStatus.working,
      jobTitle: 'Designer',
      monthlyIncomeBdt: '50,000',
      fitnessGoal: 'Run a 5K',
    );

    expect(partial.isPersonalInfoComplete, isFalse);
    expect(partial.missingPersonalInfoLabels, isNot(contains('Monthly income (BDT)')));
    expect(partial.missingPersonalInfoLabels, isNot(contains('Job title')));
    expect(partial.missingPersonalInfoLabels, isNot(contains('Employment status')));
    expect(partial.missingPersonalInfoLabels, contains('Employer'));
    expect(partial.missingPersonalInfoLabels, contains('Work address'));
    expect(partial.missingPersonalInfoLabels, contains('Weekend days'));
  });

  test('composeSystemInstruction includes user name', () {
    final config = _samplePersonalConfig();
    final system = config.composeSystemInstruction();

    expect(system, contains('- Name: Alex Morgan'));
    expect(system, contains('- Age: 28'));
    expect(system, contains('- Gender: Male'));
    expect(system, contains('- Location: Dhaka, Bangladesh'));
    expect(system, contains('- Marital status: Married'));
    expect(
      config.composeAssistantIdentity(),
      'You are a highly analytical, uncompromising personal data assistant for Alex Morgan.',
    );
    expect(system, contains(config.composeAssistantIdentity()));
  });

  test('composeAssistantIdentity uses generic role when name is empty', () {
    final config = PromptConfig.initial();

    expect(
      config.composeAssistantIdentity(),
      'You are a highly analytical, uncompromising personal data assistant.',
    );
  });

  test('composeProfessionAndSchedule joins role and schedule fields', () {
    final config = _samplePersonalConfig();

    expect(
      config.composeProfessionAndSchedule(),
      'Software Engineer at Acme Corp. Work address: 123 Main Road, Gulshan, Dhaka. Weekend days are Friday and Saturday. Work hours are 10 AM to 6 PM',
    );
    expect(
      config.composeSystemInstruction(),
      contains(
        'Profession & Schedule: Software Engineer at Acme Corp. Work address: 123 Main Road, Gulshan, Dhaka. Weekend days are Friday and Saturday. Work hours are 10 AM to 6 PM',
      ),
    );
  });

  test('fromJson migrates legacy professionAndSchedule into job title', () {
    final config = PromptConfig.fromJson({
      'professionAndSchedule':
          'Software Engineer at Catch Bangladesh LTD. Work days are Sunday to Thursday, 10 AM to 6 PM',
    });

    expect(config.jobTitle, contains('Software Engineer'));
    expect(config.employmentStatus, EmploymentStatus.working);
    expect(config.weekendDays, isEmpty);
    expect(config.employer, isEmpty);
    expect(config.workHours, isEmpty);
  });

  test('fromJson reads weekend day picker values', () {
    final config = PromptConfig.fromJson({
      'employmentStatus': 'student',
      'weekendDays': [5, 6],
    });

    expect(config.weekendDays, [5, 6]);
  });

  test('composeProfessionAndSchedule formats student profile', () {
    final config = PromptConfig.initial().copyWith(
      name: 'Sam',
      age: '22',
      gender: 'Male',
      location: 'Dhaka',
      maritalStatus: 'Single',
      employmentStatus: EmploymentStatus.student,
      schoolName: 'University of Dhaka',
      studyProgram: 'Computer Science',
      weekendDays: const [DateTime.friday, DateTime.saturday],
      studyHours: '9 AM to 3 PM',
    );

    expect(
      config.composeProfessionAndSchedule(),
      'Student at University of Dhaka studying Computer Science. Weekend days are Friday and Saturday. Study hours are 9 AM to 3 PM',
    );
  });

  test('student profile does not require monthly income', () {
    final config = PromptConfig.initial().copyWith(
      name: 'Sam',
      age: '22',
      gender: 'Male',
      location: 'Dhaka',
      maritalStatus: 'Single',
      employmentStatus: EmploymentStatus.student,
      schoolName: 'University of Dhaka',
      studyProgram: 'Computer Science',
      weekendDays: const [DateTime.friday, DateTime.saturday],
      studyHours: '9 AM to 3 PM',
      financialInstruction: 'Keep spending low.',
      fitnessGoal: 'Stay active.',
      householdLifestyle: 'Lives with parents.',
      decisionSupportRule: 'Skip impulse buys.',
    );

    expect(config.isPersonalInfoComplete, isTrue);
    expect(config.missingPersonalInfoLabels, isNot(contains('Monthly income (BDT)')));
    expect(config.composeSystemInstruction(), contains('No salary income reported'));
    expect(config.composeTemplate(), contains('Use 0 BDT as the monthly baseline.'));
  });

  test('composeProfessionAndSchedule formats unemployed profile', () {
    final config = PromptConfig.initial().copyWith(
      employmentStatus: EmploymentStatus.unemployed,
      unemploymentSituation: 'Job searching after a layoff',
      routineDays: 'Monday to Saturday',
      routineHours: '8 AM to 10 PM',
    );

    expect(
      config.composeProfessionAndSchedule(),
      'Currently unemployed: Job searching after a layoff. Typical days are Monday to Saturday, 8 AM to 10 PM',
    );
  });

  test('composeTemplate injects selected cross-domain impact metrics', () {
    final config = _samplePersonalConfig().copyWith(
      crossDomainImpacts: const ['sleep duration', 'screen time'],
      customCrossDomainImpacts: const ['screen time'],
    );
    final composed = config.composeTemplate();

    expect(composed, contains('* sleep duration'));
    expect(composed, contains('* screen time'));
    expect(composed, isNot(contains('* bedtime drift')));
    expect(composed, isNot(contains('{{crossDomainImpacts}}')));
  });

  test('fromJson defaults cross-domain impacts when missing', () {
    final config = PromptConfig.fromJson({'name': 'Jamie'});

    expect(
      config.crossDomainImpacts,
      PromptTemplateSections.defaultCrossDomainImpacts,
    );
    expect(config.customCrossDomainImpacts, isEmpty);
  });

  test('composeTemplate includes locked sections and placeholders', () {
    final config = _samplePersonalConfig();
    final composed = config.composeTemplate();

    expect(composed, contains('RULES FOR ANALYSIS:'));
    expect(composed, contains('DATA TO ANALYZE:'));
    expect(composed, contains('OUTPUT FORMAT:'));
    expect(composed, contains('{{health}}'));
    expect(composed, contains('{{location}}'));
    expect(composed, contains('{{gameActivity}}'));
    expect(composed, contains('{{calendar}}'));
    expect(composed, contains('{{focus}}'));
    expect(composed, contains(config.monthlyIncomeBdt));
    expect(composed, isNot(contains('{{monthlyIncomeBdt}}')));
    expect(composed, contains('Evidence Policy'));
    expect(composed, contains('INTERNAL ANALYSIS PIPELINE'));
    expect(composed, contains('{{focus}}'));
    expect(composed, contains('{{expenseCategories}}'));
    expect(composed, isNot(contains('{{crossDomainImpacts}}')));
    expect(
      composed,
      isNot(contains('Calculate percentages for:\n\n* discretionary spending')),
    );
    expect(composed, contains('all data-supported anomalies ranked by Anomaly Score'));
    expect(composed, contains('Clear Next Actions'));
    expect(composed, contains('{{checklistWeekSegments}}'));
    expect(composed, contains('Weekly Planning Framework'));
    expect(composed, contains('Future Events'));
    expect(composed, contains('Upcoming Schedule (Future Events)'));
    expect(composed, contains('Future Event Coverage Check'));
  });

  test('composeWeeklyVerifyTemplate includes future events calendar guidance', () {
    final config = _samplePersonalConfig();
    final composed = config.composeWeeklyVerifyTemplate();

    expect(composed, contains('Future Events'));
    expect(composed, contains('Calendar Context (Future Events)'));
    expect(composed, contains('Week data range above'));
  });

  test('composeTemplate uses edited monthly income in rules', () {
    final config = _samplePersonalConfig().copyWith(monthlyIncomeBdt: '42,000');
    final composed = config.composeTemplate();

    expect(composed, contains('Use 42,000 BDT as the monthly baseline.'));
    expect(composed, isNot(contains('Use 35,000 BDT as the financial baseline.')));
  });

  test('analysis run placeholder substitution fills data blocks', () {
    final config = _samplePersonalConfig();
    final period = AnalysisPeriod.forDataMonth(DateTime(2026, 5, 1));

    final rendered = config
        .composeTemplate()
        .replaceAll('{{focus}}', config.focus)
        .replaceAll('{{analysisMonth}}', period.dataRangeLabel)
        .replaceAll('{{health}}', 'sleep data')
        .replaceAll('{{expenses}}', 'expense data')
        .replaceAll('{{expenseCategories}}', '* food')
        .replaceAll('{{location}}', 'location data')
        .replaceAll('{{gameActivity}}', 'game data')
        .replaceAll('{{calendar}}', 'calendar data')
        .replaceAll('{{totalRealExpenses}}', '1000 BDT');

    expect(rendered, contains('sleep data'));
    expect(rendered, contains('May 2026'));
    expect(rendered, isNot(contains('{{health}}')));
  });

  test('composeSystemInstruction includes financial baseline from form', () {
    final config = _samplePersonalConfig().copyWith(monthlyIncomeBdt: '50,000');
    final system = config.composeSystemInstruction();

    expect(system, contains('Monthly income is 50,000 BDT'));
  });

  test('composeSystemInstruction does not inject hardcoded personal defaults', () {
    final config = PromptConfig.initial();
    final system = config.composeSystemInstruction();

    expect(system, isNot(contains('Rafid Rahman')));
    expect(system, isNot(contains('Catch Bangladesh')));
    expect(system, contains('Profession & Schedule:'));
    expect(system, contains('No salary income reported'));
  });

  test('toPersonalInfoJson includes personal fields and excludes prompt fields', () {
    final config = _samplePersonalConfig().copyWith(
      assistantIdentity: 'Custom identity',
      toneInstruction: 'Custom tone',
      focus: 'Custom focus',
    );
    final personal = config.toPersonalInfoJson();

    expect(personal, containsPair('name', 'Alex Morgan'));
    expect(personal, containsPair('monthlyIncomeBdt', '80,000'));
    expect(personal, isNot(contains('assistantIdentity')));
    expect(personal, isNot(contains('toneInstruction')));
    expect(personal, isNot(contains('focus')));
  });

  test('mergePersonalInfo updates profile fields but keeps system prompt fields', () {
    final local = PromptConfig.initial().copyWith(
      assistantIdentity: 'Keep me',
      toneInstruction: 'Keep tone',
      focus: 'Keep focus',
      name: 'Old name',
    );
    final cloud = _samplePersonalConfig().toPersonalInfoJson();

    final merged = local.mergePersonalInfo(cloud);

    expect(merged.name, 'Alex Morgan');
    expect(merged.monthlyIncomeBdt, '80,000');
    expect(merged.assistantIdentity, 'Keep me');
    expect(merged.toneInstruction, 'Keep tone');
    expect(merged.focus, 'Keep focus');
  });

  test('personal info round trip through merge and toPersonalInfoJson is stable', () {
    final original = _samplePersonalConfig();
    final merged = PromptConfig.initial().mergePersonalInfo(
      original.toPersonalInfoJson(),
    );

    expect(merged.toPersonalInfoJson(), original.toPersonalInfoJson());
  });

  test('fromLegacyJson keeps identity and tone from legacy template', () {
    final legacy = PromptConfig.fromLegacyJson({
      'template': 'My custom intro.\n\nRULES FOR ANALYSIS:\n1. Rule one.',
      'focus': 'Weekly spend',
    });

    expect(legacy.assistantIdentity, 'My custom intro.');
    expect(legacy.focus, 'Weekly spend');
    expect(legacy.composeTemplate(), isNot(contains('1. Rule one.')));
    expect(legacy.composeTemplate(), contains('RULES FOR ANALYSIS:'));
  });
}
