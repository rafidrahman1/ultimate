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

part 'personal_information_sections.dart';
part 'personal_information_widgets.dart';

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
  final _rideController = TextEditingController();
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
    _rideController.dispose();
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
    _rideController.text = config.ride;
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
      ride: _rideController.text.trim(),
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

  /// `setState` for the section builders in `personal_information_sections.dart`.
  void _update(VoidCallback fn) => setState(fn);

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

            return ContentWidth(
              child: ListView(
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
                  _aboutSection(context, draft),
                  const SizedBox(height: 32),
                  _professionSection(context, draft),
                  const SizedBox(height: 32),
                  _goalsSection(context, draft),
                ],
              ),
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
