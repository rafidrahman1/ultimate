import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/error_display.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/analysis/analysis_reports_storage.dart';
import 'package:personal/features/analysis/month_end_analysis_notification_service.dart';
import 'package:personal/features/dashboard/predictions/prediction_calendar_service.dart';
import 'package:personal/features/dashboard/predictions/prediction_notification_service.dart';
import 'package:personal/features/results/ai/ai_client.dart';
import 'package:personal/features/results/reports/results_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/features/settings/settings_status.dart';
import 'package:personal/features/settings/widgets/ai_settings_section.dart';
import 'package:personal/features/settings/widgets/backup_section.dart';
import 'package:personal/features/settings/widgets/notifications_card.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/data_folder_picker_section.dart';
import 'package:personal/shared/widgets/section_header.dart';
import 'package:personal/shared/widgets/status_message.dart';

class GeneralSettingsScreen extends ConsumerStatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  ConsumerState<GeneralSettingsScreen> createState() =>
      _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends ConsumerState<GeneralSettingsScreen> {
  final _openAiKeyController = TextEditingController();
  final _openAiModelController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  final _geminiModelController = TextEditingController();
  final _anthropicKeyController = TextEditingController();
  final _anthropicModelController = TextEditingController();

  AiProvider _provider = AiProvider.openai;
  bool _enableApiCalls = true;
  bool _monthEndReminderEnabled = true;
  bool _reminderLoading = true;
  bool _weekEndReminderEnabled = true;
  bool _predictionRemindersEnabled = true;
  bool _odometerReminderEnabled = true;
  ReminderTimes _reminderTimes = const ReminderTimes();
  bool _predictionCalendarEnabled = false;
  bool _dirty = false;
  bool _initialized = false;
  final _storageKey = GlobalKey();
  final _notificationsKey = GlobalKey();
  final _aiKey = GlobalKey();
  bool _scrolledToSection = false;

  @override
  void initState() {
    super.initState();
    _loadReminderState();
  }

  @override
  void dispose() {
    _openAiKeyController.dispose();
    _openAiModelController.dispose();
    _geminiKeyController.dispose();
    _geminiModelController.dispose();
    _anthropicKeyController.dispose();
    _anthropicModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(aiSettingsProvider);

    ref.listen(aiSettingsProvider, (_, next) {
      final value = next.valueOrNull;
      if (value == null || _dirty) return;
      _loadFromSettings(value);
    });

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        bottomNavigationBar: _dirty
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    AppSpacing.sm,
                    AppSpacing.screen,
                    AppSpacing.md,
                  ),
                  child: FilledButton.icon(
                    onPressed: _saveAiSettings,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save changes'),
                  ),
                ),
              )
            : null,
        appBar: AppScreenAppBar.build(
          context,
          ref,
          title: 'General settings',
          extraActions: [
            AppBarCircularAction(
              icon: Icons.restart_alt,
              onPressed: () async {
                await ref.read(aiSettingsProvider.notifier).reset();
                if (!mounted) return;
                setState(() => _dirty = false);
              },
            ),
          ],
        ),
        body: settingsAsync.when(
          data: (settings) {
            if (!_initialized) {
              _loadFromSettings(settings);
              _initialized = true;
            }
            _scrollToRequestedSection();
            return ContentWidth(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                children: [
                  KeyedSubtree(
                    key: _storageKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DataFolderPickerSection(
                          onFolderChanged: () {
                            AnalysisReportsStorage.instance.invalidateCache();
                            ref.invalidate(analysisResultsProvider);
                            ref.invalidate(backupInfoProvider);
                          },
                        ),
                        const SizedBox(height: 32),
                        const SectionHeader(
                          'Backup',
                          subtitle:
                              'Saves settings and checklist progress next to your '
                              'reports so a reinstall loses nothing.',
                        ),
                        const SizedBox(height: 12),
                        const BackupSection(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  KeyedSubtree(
                    key: _notificationsKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(
                          'Notifications',
                          subtitle:
                              'Local reminders and a heads-up when an analysis '
                              'finishes while you are away.',
                        ),
                        const SizedBox(height: 12),
                        NotificationsCard(
                          reminderLoading: _reminderLoading,
                          times: _reminderTimes,
                          monthEndEnabled: _monthEndReminderEnabled,
                          weekEndEnabled: _weekEndReminderEnabled,
                          predictionRemindersEnabled:
                              _predictionRemindersEnabled,
                          predictionCalendarEnabled: _predictionCalendarEnabled,
                          odometerEnabled: _odometerReminderEnabled,
                          onMonthEnd: _setMonthEndReminder,
                          onWeekEnd: _setWeekEndReminder,
                          onPredictionReminders: _setPredictionReminders,
                          onPredictionCalendar: _setPredictionCalendar,
                          onOdometer: _setOdometerReminder,
                          onPickLead: _pickLead,
                          onPickTime: _pickTime,
                          onPickDigest: _pickDigest,
                          onSendTest: _sendTestNotification,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  KeyedSubtree(
                    key: _aiKey,
                    child: const SectionHeader(
                      'AI',
                      subtitle:
                          'Configure both providers and choose which one to use for '
                          'analysis. Turn off API calls to use local fallback text only.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  AiSettingsSection(
                    enableApiCalls: _enableApiCalls,
                    provider: _provider,
                    openAiKeyController: _openAiKeyController,
                    openAiModelController: _openAiModelController,
                    geminiKeyController: _geminiKeyController,
                    geminiModelController: _geminiModelController,
                    anthropicKeyController: _anthropicKeyController,
                    anthropicModelController: _anthropicModelController,
                    onEnableApiCallsChanged: (enabled) => setState(() {
                      _enableApiCalls = enabled;
                      _dirty = true;
                    }),
                    onProviderChanged: (value) => setState(() {
                      _provider = value;
                      _dirty = true;
                    }),
                    onChanged: _markDirty,
                    onTest: _testProvider,
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StatusMessage(
            icon: Icons.error_outline,
            title: 'Could not load settings',
            subtitle: humanizeError(error),
          ),
        ),
      ),
    );
  }

  void _markDirty() => setState(() => _dirty = true);

  /// Opens at the section the caller asked for (route argument).
  void _scrollToRequestedSection() {
    if (_scrolledToSection) return;
    _scrolledToSection = true;
    final section = ModalRoute.of(context)?.settings.arguments;
    final key = switch (section) {
      'storage' => _storageKey,
      'notifications' => _notificationsKey,
      'ai' => _aiKey,
      _ => null,
    };
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _setWeekEndReminder(bool enabled) async {
    setState(() => _weekEndReminderEnabled = enabled);
    await MonthEndAnalysisNotificationService.setWeekEndChecklistReminderEnabled(
      enabled,
    );
  }

  Future<void> _setPredictionReminders(bool enabled) async {
    setState(() => _predictionRemindersEnabled = enabled);
    await PredictionNotificationService.setPredictionRemindersEnabled(enabled);
  }

  Future<void> _setPredictionCalendar(bool enabled) async {
    setState(() => _predictionCalendarEnabled = enabled);
    try {
      await PredictionCalendarService.setEnabled(enabled);
    } catch (error) {
      if (!mounted) return;
      setState(() => _predictionCalendarEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is FormatException ? error.message : '$error'),
        ),
      );
    }
  }

  Future<void> _setOdometerReminder(bool enabled) async {
    setState(() => _odometerReminderEnabled = enabled);
    await PredictionNotificationService.setOdometerReminderEnabled(enabled);
  }

  Future<void> _reloadTimes() async {
    final times = await PredictionNotificationService.loadTimes();
    if (mounted) setState(() => _reminderTimes = times);
  }

  Future<int?> _askTime(int initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  Future<void> _pickTime(
    int initial,
    Future<void> Function(int minutes) save,
  ) async {
    final minutes = await _askTime(initial);
    if (minutes == null) return;
    await save(minutes);
    await _reloadTimes();
  }

  Future<void> _pickLead() async {
    final lead = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Remind me'),
        children: [
          for (final (days, label) in const [
            (0, 'On the day'),
            (1, 'The day before'),
            (2, '2 days before'),
            (3, '3 days before'),
            (7, 'A week before'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, days),
              child: Text(label),
            ),
        ],
      ),
    );
    if (lead == null) return;
    await PredictionNotificationService.saveTimes(leadDays: lead);
    await _reloadTimes();
  }

  Future<void> _pickDigest() async {
    final day = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Weekly summary day'),
        children: [
          for (var i = 0; i < 7; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i + 1),
              child: Text(kWeekdayNames[i]),
            ),
        ],
      ),
    );
    if (day == null || !mounted) return;
    final minutes = await _askTime(_reminderTimes.digestMinutes);
    await PredictionNotificationService.saveTimes(
      digestWeekday: day,
      digestMinutes: minutes,
    );
    await _reloadTimes();
  }

  Future<void> _sendTestNotification() async {
    await MonthEndAnalysisNotificationService.showAnalysisFinished(
      title: 'Test notification',
      body: 'Alerts from Personal are working.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sent. If nothing appears, allow notifications for Personal in system settings.',
        ),
      ),
    );
  }

  Future<void> _confirmDiscard() async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Save your AI settings before leaving?'),
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
    if (action == 'save') await _saveAiSettings();
    if (!mounted) return;
    if (action == 'discard' || !_dirty) {
      setState(() => _dirty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  /// Sends a tiny prompt with the values currently in the form.
  Future<String?> _testProvider(AiProvider provider) async {
    final settings = AiSettings(
      provider: provider,
      openAiApiKey: _openAiKeyController.text.trim(),
      openAiModel: _openAiModelController.text.trim(),
      geminiApiKey: _geminiKeyController.text.trim(),
      geminiModel: _geminiModelController.text.trim(),
      anthropicApiKey: _anthropicKeyController.text.trim(),
      anthropicModel: _anthropicModelController.text.trim(),
      enableApiCalls: true,
    );
    final key = switch (provider) {
      AiProvider.openai => settings.openAiApiKey,
      AiProvider.gemini => settings.geminiApiKey,
      AiProvider.anthropic => settings.anthropicApiKey,
    };
    if (key.isEmpty) return 'Enter an API key first';
    try {
      await const AiClient(
        requestTimeout: Duration(seconds: 30),
        totalBudget: Duration(seconds: 40),
        maxAttempts: 1,
      ).generate(settings: settings, prompt: 'Reply with the single word OK.');
      return null;
    } catch (error) {
      return humanizeError(error);
    }
  }

  Future<void> _setMonthEndReminder(bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _monthEndReminderEnabled = enabled);
    await MonthEndAnalysisNotificationService.setReminderEnabled(enabled);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Month-end reminder enabled'
              : 'Month-end reminder disabled',
        ),
      ),
    );
  }

  Future<void> _saveAiSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    final openAiKey = _openAiKeyController.text.trim();
    final openAiModel = _openAiModelController.text.trim();
    final geminiKey = _geminiKeyController.text.trim();
    final geminiModel = _geminiModelController.text.trim();
    final anthropicKey = _anthropicKeyController.text.trim();
    final anthropicModel = _anthropicModelController.text.trim();

    if (_enableApiCalls &&
        _provider == AiProvider.openai &&
        openAiKey.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('OpenAI API key is required')),
      );
      return;
    }
    if (_enableApiCalls &&
        _provider == AiProvider.gemini &&
        geminiKey.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gemini API key is required')),
      );
      return;
    }
    if (_enableApiCalls &&
        _provider == AiProvider.anthropic &&
        anthropicKey.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Anthropic API key is required')),
      );
      return;
    }

    final next = AiSettings(
      provider: _provider,
      openAiApiKey: openAiKey,
      openAiModel: openAiModel.isEmpty
          ? AiSettings.initial().openAiModel
          : openAiModel,
      geminiApiKey: geminiKey,
      geminiModel: geminiModel.isEmpty
          ? AiSettings.initial().geminiModel
          : geminiModel,
      anthropicApiKey: anthropicKey,
      anthropicModel: anthropicModel.isEmpty
          ? AiSettings.initial().anthropicModel
          : anthropicModel,
      enableApiCalls: _enableApiCalls,
    );
    await ref.read(aiSettingsProvider.notifier).save(next);
    if (!mounted) return;
    setState(() => _dirty = false);
    messenger.showSnackBar(const SnackBar(content: Text('AI settings saved')));
  }

  void _loadFromSettings(AiSettings value) {
    _provider = value.provider;
    _enableApiCalls = value.enableApiCalls;
    _openAiKeyController.text = value.openAiApiKey;
    _openAiModelController.text = value.openAiModel;
    _geminiKeyController.text = value.geminiApiKey;
    _geminiModelController.text = value.geminiModel;
    _anthropicKeyController.text = value.anthropicApiKey;
    _anthropicModelController.text = value.anthropicModel;
  }

  Future<void> _loadReminderState() async {
    final enabled =
        await MonthEndAnalysisNotificationService.isReminderEnabled();
    final weekEnabled =
        await MonthEndAnalysisNotificationService.isWeekEndChecklistReminderEnabled();
    final predictionsEnabled =
        await PredictionNotificationService.isPredictionRemindersEnabled();
    final odometerEnabled =
        await PredictionNotificationService.isOdometerReminderEnabled();
    final calendarEnabled = await PredictionCalendarService.isEnabled();
    final times = await PredictionNotificationService.loadTimes();
    if (!mounted) return;
    setState(() {
      _reminderTimes = times;
      _predictionCalendarEnabled = calendarEnabled;
      _monthEndReminderEnabled = enabled;
      _weekEndReminderEnabled = weekEnabled;
      _predictionRemindersEnabled = predictionsEnabled;
      _odometerReminderEnabled = odometerEnabled;
      _reminderLoading = false;
    });
  }
}
