import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/time_range_schedule.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/features/prompts/widgets/time_range_picker_field.dart';
import 'package:personal/features/prompts/widgets/cross_domain_impact_picker.dart';
import 'package:personal/features/prompts/widgets/weekend_day_picker.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/calendar_service.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';

enum _SaveChoice { signIn, localOnly }

class PersonalInformationScreen extends ConsumerStatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  ConsumerState<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState
    extends ConsumerState<PersonalInformationScreen> {
  EmploymentStatus? _employmentStatus;
  Set<int> _weekendDays = {};
  TimeOfDay? _workStart;
  TimeOfDay? _workEnd;
  TimeOfDay? _studyStart;
  TimeOfDay? _studyEnd;
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  String? _gender;
  String? _maritalStatus;
  final _jobTitleController = TextEditingController();
  final _employerController = TextEditingController();
  final _workAddressController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _studyProgramController = TextEditingController();
  final _unemploymentSituationController = TextEditingController();
  final _routineDaysController = TextEditingController();
  final _routineHoursController = TextEditingController();
  final _incomeController = TextEditingController();
  final _financialController = TextEditingController();
  final _fitnessController = TextEditingController();
  final _lifestyleController = TextEditingController();
  final _decisionSupportController = TextEditingController();
  List<String> _crossDomainImpacts = [];
  List<String> _customCrossDomainImpacts = [];
  bool _dirty = false;
  bool _syncing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _jobTitleController.dispose();
    _employerController.dispose();
    _workAddressController.dispose();
    _schoolNameController.dispose();
    _studyProgramController.dispose();
    _unemploymentSituationController.dispose();
    _routineDaysController.dispose();
    _routineHoursController.dispose();
    _incomeController.dispose();
    _financialController.dispose();
    _fitnessController.dispose();
    _lifestyleController.dispose();
    _decisionSupportController.dispose();
    super.dispose();
  }

  void _syncFromConfig(PromptConfig config) {
    _nameController.text = config.name;
    _ageController.text = config.age;
    _gender = config.gender.isEmpty ? null : config.gender;
    _locationController.text = config.location;
    _maritalStatus =
        config.maritalStatus.isEmpty ? null : config.maritalStatus;
    _employmentStatus = config.employmentStatus;
    _weekendDays = config.weekendDays.toSet();
    _jobTitleController.text = config.jobTitle;
    _employerController.text = config.employer;
    _workAddressController.text = config.workAddress;
    final workRange = parseTimeRangeLabel(config.workHours);
    _workStart = workRange?.start;
    _workEnd = workRange?.end;
    _schoolNameController.text = config.schoolName;
    _studyProgramController.text = config.studyProgram;
    final studyRange = parseTimeRangeLabel(config.studyHours);
    _studyStart = studyRange?.start;
    _studyEnd = studyRange?.end;
    _unemploymentSituationController.text = config.unemploymentSituation;
    _routineDaysController.text = config.routineDays;
    _routineHoursController.text = config.routineHours;
    _incomeController.text = config.monthlyIncomeBdt;
    _financialController.text = config.financialInstruction;
    _fitnessController.text = config.fitnessGoal;
    _lifestyleController.text = config.householdLifestyle;
    _decisionSupportController.text = config.decisionSupportRule;
    _crossDomainImpacts = List<String>.from(config.crossDomainImpacts);
    _customCrossDomainImpacts = List<String>.from(config.customCrossDomainImpacts);
  }

  PromptConfig _draftFromControllers(PromptConfig base) {
    return base.copyWith(
      name: _nameController.text.trim(),
      age: _ageController.text.trim(),
      gender: _gender?.trim() ?? '',
      location: _locationController.text.trim(),
      maritalStatus: _maritalStatus?.trim() ?? '',
      employmentStatus: _employmentStatus,
      clearEmploymentStatus: _employmentStatus == null,
      weekendDays: _weekendDays.toList()..sort(),
      jobTitle: _jobTitleController.text.trim(),
      employer: _employerController.text.trim(),
      workAddress: _workAddressController.text.trim(),
      workHours: formatTimeRange(_workStart, _workEnd),
      schoolName: _schoolNameController.text.trim(),
      studyProgram: _studyProgramController.text.trim(),
      studyHours: formatTimeRange(_studyStart, _studyEnd),
      unemploymentSituation: _unemploymentSituationController.text.trim(),
      routineDays: _routineDaysController.text.trim(),
      routineHours: _routineHoursController.text.trim(),
      monthlyIncomeBdt: _employmentStatus == EmploymentStatus.working
          ? _incomeController.text.trim()
          : '',
      financialInstruction: _financialController.text.trim(),
      fitnessGoal: _fitnessController.text.trim(),
      householdLifestyle: _lifestyleController.text.trim(),
      decisionSupportRule: _decisionSupportController.text.trim(),
      crossDomainImpacts: List<String>.from(_crossDomainImpacts),
      customCrossDomainImpacts: List<String>.from(_customCrossDomainImpacts),
    );
  }

  String _employmentStatusLabel(EmploymentStatus status) => switch (status) {
    EmploymentStatus.working => 'Working',
    EmploymentStatus.student => 'Student',
    EmploymentStatus.unemployed => 'Unemployed',
  };

  Future<_SaveChoice?> _promptSignInForSync() {
    return showDialog<_SaveChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign in with Google?'),
        content: const Text(
          'Use the same Google account for calendar sync and cloud backup of '
          'your personal information across devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _SaveChoice.localOnly),
            child: const Text('Save locally only'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, _SaveChoice.signIn),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  String _saveSnackBarMessage({
    required PromptConfig next,
    required PromptConfigSaveResult result,
  }) {
    if (result.syncedToCloud) {
      return next.isPersonalInfoComplete
          ? 'Saved and synced'
          : 'Saved and synced — fill remaining fields to enable analysis';
    }
    if (result.syncError != null) {
      return 'Saved on this device — sync failed';
    }
    return next.isPersonalInfoComplete
        ? 'Personal information saved'
        : 'Saved — fill remaining fields to enable analysis';
  }

  Future<void> _savePersonalInformation(
    BuildContext context,
    PromptConfig config,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final next = _draftFromControllers(config);
    final accountService = ref.read(googleAccountServiceProvider);
    var syncToCloud = accountService.isSignedIn;

    if (!syncToCloud) {
      final choice = await _promptSignInForSync();
      if (!mounted) return;
      if (choice == null) return;

      if (choice == _SaveChoice.signIn) {
        try {
          final result = await accountService.signIn();
          await ref.read(calendarSummaryProvider.notifier).persistGoogleConnection(
            email: result.account.email,
            photoUrl: result.account.photoUrl,
            displayName:
                result.account.displayName ?? result.firebaseUser.displayName,
          );
          syncToCloud = true;
        } catch (error) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(content: Text('Google sign-in failed: $error')),
          );
          return;
        }
      }
    }

    final result = await ref
        .read(promptConfigProvider.notifier)
        .save(next, syncToCloud: syncToCloud);
    if (!mounted) return;
    setState(() => _dirty = false);
    messenger.showSnackBar(
      SnackBar(content: Text(_saveSnackBarMessage(next: next, result: result))),
    );
  }

  Future<bool> _promptSignInForCloudPull() async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign in with Google?'),
        content: const Text(
          'Sign in to load your personal information from the cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
    return choice == true;
  }

  Future<bool> _confirmDiscardLocalChangesForSync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sync from cloud?'),
        content: const Text(
          'You have unsaved changes on this device. Syncing will replace them '
          'with data from your cloud backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sync'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  String _syncSnackBarMessage(PersonalInfoSyncResult result) {
    if (result.synced) return 'Personal information synced from cloud';
    if (result.notSignedIn) return 'Sign in required to sync from cloud';
    if (result.noCloudData) {
      return 'No cloud backup found — save to create one';
    }
    if (result.error != null) return 'Sync failed — try again later';
    return 'Sync failed';
  }

  Future<void> _syncPersonalInformationFromDatabase() async {
    if (_syncing) return;

    final messenger = ScaffoldMessenger.of(context);

    if (_dirty) {
      final confirmed = await _confirmDiscardLocalChangesForSync();
      if (!confirmed || !mounted) return;
    }

    final accountService = ref.read(googleAccountServiceProvider);
    if (!accountService.isSignedIn) {
      final shouldSignIn = await _promptSignInForCloudPull();
      if (!mounted) return;
      if (!shouldSignIn) return;

      try {
        final result = await accountService.signIn();
        await ref.read(calendarSummaryProvider.notifier).persistGoogleConnection(
          email: result.account.email,
          photoUrl: result.account.photoUrl,
          displayName:
              result.account.displayName ?? result.firebaseUser.displayName,
        );
      } catch (error) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Google sign-in failed: $error')),
        );
        return;
      }
    }

    setState(() => _syncing = true);
    final result = await ref
        .read(promptConfigProvider.notifier)
        .pullPersonalInfoFromCloud();
    if (!mounted) return;

    final config = ref.read(promptConfigProvider).valueOrNull;
    setState(() {
      _syncing = false;
      if (result.synced && config != null) {
        _syncFromConfig(config);
        _dirty = false;
      }
    });
    messenger.showSnackBar(
      SnackBar(content: Text(_syncSnackBarMessage(result))),
    );
  }

  String _syncStatusLabel(AsyncValue authState) {
    return authState.when(
      data: (user) {
        if (user == null) {
          return 'Local only — sign in from Google account settings or on save';
        }
        final label = user.displayName ?? user.email;
        if (label == null || label.isEmpty) {
          return 'Signed in — calendar and profile sync on save';
        }
        return 'Signed in as $label — calendar and profile sync enabled';
      },
      loading: () => 'Checking Google account…',
      error: (_, _) => 'Local only',
    );
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(promptConfigProvider);
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);
    final config = configAsync.valueOrNull;

    ref.listen(promptConfigProvider, (_, next) {
      final value = next.valueOrNull;
      if (value == null || _dirty) return;
      _syncFromConfig(value);
    });

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Personal information',
        extraActions: [
          AppBarCircularAction(
            icon: Icons.sync,
            onPressed: _syncing ? null : _syncPersonalInformationFromDatabase,
          ),
        ],
      ),
      floatingActionButton: config == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _savePersonalInformation(context, config),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
      body: configAsync.when(
        data: (config) {
          if (_employmentStatus == null && config.employmentStatus != null && !_dirty) {
            _syncFromConfig(config);
          } else if (!_dirty && _incomeController.text.isEmpty) {
            _syncFromConfig(config);
          }

          final draft = _draftFromControllers(config);
          final isComplete = draft.isPersonalInfoComplete;
          final missing = draft.missingPersonalInfoLabels;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
            children: [
              Text(
                'Tell the assistant about you',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'These details are injected into every analysis run. '
                'Analysis stays disabled until all fields below are filled in.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _syncStatusLabel(authState),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _CompletionBanner(isComplete: isComplete, missing: missing),
              const SizedBox(height: 16),
              Text(
                'About you',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Your full name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  hintText: 'e.g. 28',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Select gender'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                ],
                onChanged: (value) => setState(() {
                  _gender = value;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. Dhaka, Bangladesh',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _maritalStatus,
                decoration: const InputDecoration(
                  labelText: 'Marital status',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Select marital status'),
                items: const [
                  DropdownMenuItem(value: 'Single', child: Text('Single')),
                  DropdownMenuItem(
                    value: 'In a relationship',
                    child: Text('In a relationship'),
                  ),
                  DropdownMenuItem(value: 'Married', child: Text('Married')),
                  DropdownMenuItem(value: 'Divorced', child: Text('Divorced')),
                  DropdownMenuItem(value: 'Widowed', child: Text('Widowed')),
                ],
                onChanged: (value) => setState(() {
                  _maritalStatus = value;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'Profession and schedule',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<EmploymentStatus>(
                initialValue: _employmentStatus,
                decoration: const InputDecoration(
                  labelText: 'Profession',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Select your profession'),
                items: [
                  for (final status in EmploymentStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(_employmentStatusLabel(status)),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _employmentStatus = value;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 12),
              if (_employmentStatus == EmploymentStatus.working) ...[
                TextField(
                  controller: _jobTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Job title',
                    hintText: 'e.g. Software Engineer L1 (Flutter Developer)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _employerController,
                  decoration: const InputDecoration(
                    labelText: 'Employer',
                    hintText: 'e.g. Catch Bangladesh LTD',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _workAddressController,
                  minLines: 2,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Work address',
                    hintText: 'e.g. 123 Main Road, Gulshan, Dhaka',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                WeekendDayPicker(
                  selectedWeekdays: _weekendDays,
                  helperText: 'Select the days you are off work.',
                  onChanged: (days) => setState(() {
                    _weekendDays = days;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 12),
                TimeRangePickerField(
                  label: 'Work hours',
                  start: _workStart,
                  end: _workEnd,
                  helperText: 'Pick your usual start and end times.',
                  onChanged: (start, end) => setState(() {
                    _workStart = start;
                    _workEnd = end;
                    _dirty = true;
                  }),
                ),
              ] else if (_employmentStatus == EmploymentStatus.student) ...[
                TextField(
                  controller: _schoolNameController,
                  decoration: const InputDecoration(
                    labelText: 'School or university',
                    hintText: 'e.g. University of Dhaka',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _studyProgramController,
                  decoration: const InputDecoration(
                    labelText: 'Program or major',
                    hintText: 'e.g. Computer Science',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                WeekendDayPicker(
                  selectedWeekdays: _weekendDays,
                  helperText: 'Select the days you are off from classes.',
                  onChanged: (days) => setState(() {
                    _weekendDays = days;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 12),
                TimeRangePickerField(
                  label: 'Study hours',
                  start: _studyStart,
                  end: _studyEnd,
                  helperText: 'Pick your usual class or study times.',
                  onChanged: (start, end) => setState(() {
                    _studyStart = start;
                    _studyEnd = end;
                    _dirty = true;
                  }),
                ),
              ] else if (_employmentStatus == EmploymentStatus.unemployed) ...[
                TextField(
                  controller: _unemploymentSituationController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Current situation',
                    hintText: 'e.g. Job searching, career break, caregiving',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _routineDaysController,
                  decoration: const InputDecoration(
                    labelText: 'Typical days',
                    hintText: 'e.g. Monday to Saturday',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _routineHoursController,
                  decoration: const InputDecoration(
                    labelText: 'Typical hours',
                    hintText: 'e.g. 8 AM to 10 PM',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
              ] else
                Text(
                  'Select a profession above to show the right fields.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 16),
              if (_employmentStatus == EmploymentStatus.working) ...[
                TextField(
                  controller: _incomeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monthly income (BDT)',
                    hintText: 'e.g. 80000',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _financialController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Financial rules',
                  hintText: 'Budget constraints and spending expectations',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fitnessController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Fitness goal',
                  hintText: 'Body goal, activity target, recovery requirements',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lifestyleController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Household and lifestyle',
                  hintText: 'Personal context that affects recommendations',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _decisionSupportController,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Decision support rule',
                  hintText: 'How Buy/Skip or other verdicts should be handled',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 16),
              CrossDomainImpactPicker(
                selectedImpacts: _crossDomainImpacts,
                customImpacts: _customCrossDomainImpacts,
                onChanged: ({required selectedImpacts, required customImpacts}) {
                  setState(() {
                    _crossDomainImpacts = selectedImpacts;
                    _customCrossDomainImpacts = customImpacts;
                    _dirty = true;
                  });
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Could not load personal information',
          subtitle: error.toString(),
        ),
      ),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.isComplete, required this.missing});

  final bool isComplete;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isComplete) {
      return Card(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        child: ListTile(
          leading: Icon(Icons.check_circle_outline, color: colorScheme.primary),
          title: const Text('Ready for analysis'),
          subtitle: const Text('All personal information fields are complete.'),
        ),
      );
    }

    return Card(
      color: colorScheme.errorContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'Incomplete profile',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Still needed:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 4),
            ...missing.map(
              (label) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $label',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
