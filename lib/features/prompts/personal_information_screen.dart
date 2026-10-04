import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/error_display.dart';
import 'package:personal/core/time_range_schedule.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/section_header.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/features/prompts/widgets/time_range_picker_field.dart';
import 'package:personal/features/prompts/widgets/cross_domain_impact_picker.dart';
import 'package:personal/features/prompts/widgets/weekend_day_picker.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/calendar_service.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/ring_gauge.dart';

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
  final _budgetController = TextEditingController();
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
    _budgetController.dispose();
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
    _maritalStatus = config.maritalStatus.isEmpty ? null : config.maritalStatus;
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
    _budgetController.text = config.monthlyBudgetBdt;
    _financialController.text = config.financialInstruction;
    _fitnessController.text = config.fitnessGoal;
    _lifestyleController.text = config.householdLifestyle;
    _decisionSupportController.text = config.decisionSupportRule;
    _crossDomainImpacts = List<String>.from(config.crossDomainImpacts);
    _customCrossDomainImpacts = List<String>.from(
      config.customCrossDomainImpacts,
    );
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
      monthlyBudgetBdt: _budgetController.text.trim(),
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
            onPressed: () =>
                Navigator.pop(dialogContext, _SaveChoice.localOnly),
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
          await ref
              .read(calendarSummaryProvider.notifier)
              .persistGoogleConnection(
                email: result.account.email,
                photoUrl: result.account.photoUrl,
                displayName:
                    result.account.displayName ??
                    result.firebaseUser.displayName,
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
      SnackBar(
        content: Text(_saveSnackBarMessage(next: next, result: result)),
      ),
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
        await ref
            .read(calendarSummaryProvider.notifier)
            .persistGoogleConnection(
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

  String _syncStatusLabel(AsyncValue<User?> authState) {
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

  final _sectionKeys = {
    'about': GlobalKey(),
    'profession': GlobalKey(),
    'goals': GlobalKey(),
  };
  final _expanded = <String, bool>{};

  static const _goalKeys = {
    'financialInstruction',
    'fitnessGoal',
    'householdLifestyle',
    'decisionSupportRule',
  };

  String _sectionOf(String key) {
    if (PromptConfig.basicPersonalInfoKeys.contains(key)) return 'about';
    if (_goalKeys.contains(key)) return 'goals';
    return 'profession';
  }

  int _missingIn(String section, PromptConfig draft) => draft
      .missingPersonalInfoKeys
      .where((key) => _sectionOf(key) == section)
      .length;

  /// Sections that start incomplete open; finished ones start folded so the
  /// form is short. After that only the user's taps change it.
  bool _isExpanded(String section, PromptConfig draft) =>
      _expanded.putIfAbsent(section, () => _missingIn(section, draft) > 0);

  void _toggleSection(String section) =>
      setState(() => _expanded[section] = !(_expanded[section] ?? false));

  void _jumpToSection(String section) {
    setState(() => _expanded[section] = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _sectionKeys[section]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _confirmLeave(PromptConfig? config) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save your personal information before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'save' && config != null) {
      await _savePersonalInformation(context, config);
    }
    if (!mounted) return;
    if (action == 'discard' || !_dirty) {
      setState(() => _dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
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

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(config);
      },
      child: Scaffold(
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
            if (_employmentStatus == null &&
                config.employmentStatus != null &&
                !_dirty) {
              _syncFromConfig(config);
            } else if (!_dirty && _incomeController.text.isEmpty) {
              _syncFromConfig(config);
            }

            final draft = _draftFromControllers(config);
            final isComplete = draft.isPersonalInfoComplete;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                20,
                AppSpacing.screen,
                96,
              ),
              children: [
                const SectionHeader(
                  'Personal information',
                  subtitle:
                      'Injected into every analysis run. Analysis stays disabled '
                      'until all required fields are filled in.',
                ),
                const SizedBox(height: 8),
                Text(
                  _syncStatusLabel(authState),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _CompletionHero(
                  draft: draft,
                  isComplete: isComplete,
                  onJump: _jumpToSection,
                ),
                const SizedBox(height: 24),
                _FormSection(
                  key: _sectionKeys['about'],
                  title: 'About you',
                  icon: Icons.badge_outlined,
                  missing: _missingIn('about', draft),
                  expanded: _isExpanded('about', draft),
                  onToggle: () => _toggleSection('about'),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              hintText: 'Your full name',
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
                            ),
                            onChanged: (_) => setState(() => _dirty = true),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _gender,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                            ),
                            hint: const Text('Select gender'),
                            items: const [
                              DropdownMenuItem(
                                value: 'Male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem(
                                value: 'Female',
                                child: Text('Female'),
                              ),
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
                            ),
                            onChanged: (_) => setState(() => _dirty = true),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _maritalStatus,
                            decoration: const InputDecoration(
                              labelText: 'Marital status',
                            ),
                            hint: const Text('Select marital status'),
                            items: const [
                              DropdownMenuItem(
                                value: 'Single',
                                child: Text('Single'),
                              ),
                              DropdownMenuItem(
                                value: 'In a relationship',
                                child: Text('In a relationship'),
                              ),
                              DropdownMenuItem(
                                value: 'Married',
                                child: Text('Married'),
                              ),
                              DropdownMenuItem(
                                value: 'Divorced',
                                child: Text('Divorced'),
                              ),
                              DropdownMenuItem(
                                value: 'Widowed',
                                child: Text('Widowed'),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              _maritalStatus = value;
                              _dirty = true;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _FormSection(
                  key: _sectionKeys['profession'],
                  title: 'Profession and schedule',
                  icon: Icons.work_outline,
                  missing: _missingIn('profession', draft),
                  expanded: _isExpanded('profession', draft),
                  onToggle: () => _toggleSection('profession'),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<EmploymentStatus>(
                            initialValue: _employmentStatus,
                            decoration: const InputDecoration(
                              labelText: 'Profession',
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
                          if (_employmentStatus ==
                              EmploymentStatus.working) ...[
                            TextField(
                              controller: _jobTitleController,
                              decoration: const InputDecoration(
                                labelText: 'Job title',
                                hintText: 'e.g. Software Engineer L1',
                              ),
                              onChanged: (_) => setState(() => _dirty = true),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _employerController,
                              decoration: const InputDecoration(
                                labelText: 'Employer',
                                hintText: 'e.g. Catch Bangladesh LTD',
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
                                alignLabelWithHint: true,
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
                              helperText:
                                  'Pick your usual start and end times.',
                              onChanged: (start, end) => setState(() {
                                _workStart = start;
                                _workEnd = end;
                                _dirty = true;
                              }),
                            ),
                          ] else if (_employmentStatus ==
                              EmploymentStatus.student) ...[
                            TextField(
                              controller: _schoolNameController,
                              decoration: const InputDecoration(
                                labelText: 'School or university',
                                hintText: 'e.g. University of Dhaka',
                              ),
                              onChanged: (_) => setState(() => _dirty = true),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _studyProgramController,
                              decoration: const InputDecoration(
                                labelText: 'Program or major',
                                hintText: 'e.g. Computer Science',
                              ),
                              onChanged: (_) => setState(() => _dirty = true),
                            ),
                            const SizedBox(height: 12),
                            WeekendDayPicker(
                              selectedWeekdays: _weekendDays,
                              helperText:
                                  'Select the days you are off from classes.',
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
                              helperText:
                                  'Pick your usual class or study times.',
                              onChanged: (start, end) => setState(() {
                                _studyStart = start;
                                _studyEnd = end;
                                _dirty = true;
                              }),
                            ),
                          ] else if (_employmentStatus ==
                              EmploymentStatus.unemployed) ...[
                            TextField(
                              controller: _unemploymentSituationController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Current situation',
                                hintText:
                                    'e.g. Job searching, career break, caregiving',
                                alignLabelWithHint: true,
                              ),
                              onChanged: (_) => setState(() => _dirty = true),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _routineDaysController,
                              decoration: const InputDecoration(
                                labelText: 'Typical days',
                                hintText: 'e.g. Monday to Saturday',
                              ),
                              onChanged: (_) => setState(() => _dirty = true),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _routineHoursController,
                              decoration: const InputDecoration(
                                labelText: 'Typical hours',
                                hintText: 'e.g. 8 AM to 10 PM',
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
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _FormSection(
                  key: _sectionKeys['goals'],
                  title: 'Goals and lifestyle',
                  icon: Icons.flag_outlined,
                  missing: _missingIn('goals', draft),
                  expanded: _isExpanded('goals', draft),
                  onToggle: () => _toggleSection('goals'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_employmentStatus ==
                                  EmploymentStatus.working) ...[
                                TextField(
                                  controller: _incomeController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Monthly income (BDT)',
                                    hintText: 'e.g. 80000',
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _dirty = true),
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextField(
                                controller: _budgetController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Monthly budget (BDT)',
                                  hintText: 'e.g. 50000',
                                  helperText:
                                      'Used for budget utilization, spending pace, and overrun calculations.',
                                ),
                                onChanged: (_) => setState(() => _dirty = true),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _financialController,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Financial rules',
                                  hintText:
                                      'Spending priorities, savings goals, and constraints',
                                  alignLabelWithHint: true,
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
                                  hintText:
                                      'Body goal, activity target, recovery requirements',
                                  alignLabelWithHint: true,
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
                                  hintText:
                                      'Personal context that affects recommendations',
                                  alignLabelWithHint: true,
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
                                  hintText:
                                      'How Buy/Skip or other verdicts should be handled',
                                  alignLabelWithHint: true,
                                ),
                                onChanged: (_) => setState(() => _dirty = true),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: CrossDomainImpactPicker(
                            selectedImpacts: _crossDomainImpacts,
                            customImpacts: _customCrossDomainImpacts,
                            onChanged:
                                ({
                                  required selectedImpacts,
                                  required customImpacts,
                                }) {
                                  setState(() {
                                    _crossDomainImpacts = selectedImpacts;
                                    _customCrossDomainImpacts = customImpacts;
                                    _dirty = true;
                                  });
                                },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StatusMessage(
            icon: Icons.error_outline,
            title: 'Could not load personal information',
            subtitle: humanizeError(error),
          ),
        ),
      ),
    );
  }
}

/// Completeness ring plus one tappable chip per missing field.
class _CompletionHero extends StatelessWidget {
  const _CompletionHero({
    required this.draft,
    required this.isComplete,
    required this.onJump,
  });

  final PromptConfig draft;
  final bool isComplete;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final total = draft.requiredPersonalInfoKeys.length;
    final missingKeys = draft.missingPersonalInfoKeys;
    final done = total - missingKeys.length;
    final percent = total == 0 ? 0.0 : done / total * 100;

    return AppCard(
      tier: isComplete ? AppCardTier.hero : AppCardTier.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RingGauge(
                percent: percent,
                color: palette.accent,
                label: 'complete',
                size: 84,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isComplete ? 'Ready for analysis' : 'Almost there',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isComplete
                          ? 'All required fields are filled in.'
                          : '$done of $total required fields done. Analysis '
                                'stays off until the rest are filled in.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (missingKeys.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('STILL NEEDED', style: context.sectionLabel),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final key in missingKeys)
                  ActionChip(
                    label: Text(
                      PromptConfig.personalInfoFieldLabels[key] ?? key,
                    ),
                    avatar: Icon(
                      Icons.arrow_outward_rounded,
                      size: 14,
                      color: palette.warning,
                    ),
                    onPressed: () => onJump(
                      PromptConfig.basicPersonalInfoKeys.contains(key)
                          ? 'about'
                          : const {
                              'financialInstruction',
                              'fitnessGoal',
                              'householdLifestyle',
                              'decisionSupportRule',
                            }.contains(key)
                          ? 'goals'
                          : 'profession',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A form block with a tappable header that shows how much is left in it.
class _FormSection extends StatelessWidget {
  const _FormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.missing,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final IconData icon;
  final int missing;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final tone = missing > 0 ? palette.warning : palette.accent;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label:
                '$title, ${missing > 0 ? '$missing fields needed' : 'complete'}',
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: tone),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: AppOpacity.medium),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        missing > 0 ? '$missing needed' : 'Done',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tone,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
