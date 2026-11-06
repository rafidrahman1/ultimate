import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/error_display.dart';
import 'package:personal/core/storage/data_folder_directory.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/forecasts/reminders/notification_setup.dart';
import 'package:personal/features/forecasts/reminders/prediction_calendar_service.dart';
import 'package:personal/features/forecasts/reminders/prediction_notification_service.dart';
import 'package:personal/features/game_activity/game_cover_service.dart';
import 'package:personal/features/results/ai/ai_client.dart';
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
  bool _reminderLoading = true;
  bool _predictionRemindersEnabled = true;
  bool _odometerReminderEnabled = true;
  ReminderTimes _reminderTimes = const ReminderTimes();
  bool _predictionCalendarEnabled = false;
  bool _dirty = false;
  bool _initialized = false;

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
    final section = _section;
    final showStorage = section == null || section == SettingsSection.storage;
    final showNotifications =
        section == null || section == SettingsSection.notifications;
    final showAi = section == null || section == SettingsSection.ai;

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
          title: switch (_section) {
            SettingsSection.storage => 'Storage & backup',
            SettingsSection.notifications => 'Notifications',
            SettingsSection.ai => 'AI provider',
            null => 'General settings',
          },
          extraActions: [
            if (_section == null || _section == SettingsSection.ai)
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
            return ContentWidth(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                children: [
                  if (showStorage)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DataFolderPickerSection(
                          onFolderChanged: () {
                            DataFolderDirectory.instance.invalidateCache();
                            ref.invalidate(backupInfoProvider);
                          },
                        ),
                        const SizedBox(height: 32),
                        const SectionHeader(
                          'Backup',
                          subtitle:
                              'Saves settings next to your reports so a reinstall '
                              'loses nothing.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const BackupSection(),
                        const SizedBox(height: 32),
                        const SectionHeader(
                          'Game cover art',
                          subtitle:
                              "Looks up each game title on Steam's public "
                              'store to show its cover. Only game names are '
                              'sent; images are cached on this device.',
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Fetch game covers'),
                          value:
                              ref
                                  .watch(gameCoversEnabledProvider)
                                  .valueOrNull ??
                              false,
                          onChanged: (enabled) => ref
                              .read(gameCoversEnabledProvider.notifier)
                              .set(enabled),
                        ),
                      ],
                    ),
                  if (showStorage && showNotifications)
                    const SizedBox(height: 32),
                  if (showNotifications)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(
                          'Notifications',
                          subtitle:
                              'Local reminders for predicted bills, refuels, '
                              'service and commutes.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        NotificationsCard(
                          reminderLoading: _reminderLoading,
                          times: _reminderTimes,
                          predictionRemindersEnabled:
                              _predictionRemindersEnabled,
                          predictionCalendarEnabled: _predictionCalendarEnabled,
                          odometerEnabled: _odometerReminderEnabled,
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
                  if ((showStorage || showNotifications) && showAi)
                    const SizedBox(height: 32),
                  if (showAi) ...[
                    const SectionHeader(
                      'AI',
                      subtitle:
                          'Configure both providers and choose which one to use for '
                          'predictions and data export. Turn off API calls to '
                          'use on-device calculations only.',
                    ),
                    const SizedBox(height: AppSpacing.md),
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

  /// The one section this page was opened for, or null for the full page.
  SettingsSection? get _section {
    final argument = ModalRoute.of(context)?.settings.arguments;
    return argument is SettingsSection ? argument : null;
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
    await NotificationSetup.showTest(
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
      _predictionRemindersEnabled = predictionsEnabled;
      _odometerReminderEnabled = odometerEnabled;
      _reminderLoading = false;
    });
  }
}
