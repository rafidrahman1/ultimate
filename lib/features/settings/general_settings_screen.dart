import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/error_display.dart';
import 'package:personal/features/analysis/analysis_reports_storage.dart';
import 'package:personal/features/analysis/month_end_analysis_notification_service.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/features/results/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/features/settings/widgets/ai_provider_section.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/data_folder_picker_section.dart';
import 'package:personal/shared/widgets/section_header.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/core/theme/app_theme.dart';

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
    final theme = Theme.of(context);

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
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                DataFolderPickerSection(
                  onFolderChanged: () {
                    AnalysisReportsStorage.instance.invalidateCache();
                    ref.invalidate(analysisResultsProvider);
                  },
                ),
                const SizedBox(height: 32),
                const SectionHeader(
                  'Notifications',
                  subtitle: 'Local reminders for month-end analysis.',
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Month-end analysis reminder'),
                        subtitle: Text(
                          _reminderLoading
                              ? 'Loading reminder preference...'
                              : 'Notify at month end to analyze the next month.',
                        ),
                        value: _monthEndReminderEnabled,
                        onChanged: _reminderLoading
                            ? null
                            : (enabled) => _setMonthEndReminder(enabled),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const SectionHeader(
                  'AI',
                  subtitle:
                      'Configure both providers and choose which one to use for '
                      'analysis. Turn off API calls to use local fallback text only.',
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable AI API calls'),
                        subtitle: const Text(
                          'When off, analysis uses local fallback insights only.',
                        ),
                        value: _enableApiCalls,
                        onChanged: (enabled) {
                          setState(() {
                            _enableApiCalls = enabled;
                            _dirty = true;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Preferred provider',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SegmentedButton<AiProvider>(
                        segments: const [
                          ButtonSegment(
                            value: AiProvider.openai,
                            label: Text('OpenAI'),
                          ),
                          ButtonSegment(
                            value: AiProvider.gemini,
                            label: Text('Gemini'),
                          ),
                          ButtonSegment(
                            value: AiProvider.anthropic,
                            label: Text('Claude'),
                          ),
                        ],
                        selected: {_provider},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _provider = selection.first;
                            _dirty = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AiProviderSection(
                  title: 'OpenAI',
                  icon: Icons.auto_awesome_outlined,
                  keyLabel: 'OpenAI API key',
                  keyHint: 'sk-...',
                  modelLabel: 'OpenAI model',
                  keyController: _openAiKeyController,
                  modelController: _openAiModelController,
                  isActive: _provider == AiProvider.openai,
                  onChanged: _markDirty,
                  onTest: () => _testProvider(AiProvider.openai),
                ),
                const SizedBox(height: AppSpacing.sm),
                AiProviderSection(
                  title: 'Gemini',
                  icon: Icons.diamond_outlined,
                  keyLabel: 'Gemini API key',
                  keyHint: 'AIza...',
                  modelLabel: 'Gemini model',
                  keyController: _geminiKeyController,
                  modelController: _geminiModelController,
                  isActive: _provider == AiProvider.gemini,
                  onChanged: _markDirty,
                  onTest: () => _testProvider(AiProvider.gemini),
                ),
                const SizedBox(height: AppSpacing.sm),
                AiProviderSection(
                  title: 'Claude (Anthropic)',
                  icon: Icons.psychology_alt_outlined,
                  keyLabel: 'Anthropic API key',
                  keyHint: 'sk-ant-...',
                  modelLabel: 'Claude model',
                  keyController: _anthropicKeyController,
                  modelController: _anthropicModelController,
                  isActive: _provider == AiProvider.anthropic,
                  onChanged: _markDirty,
                  onTest: () => _testProvider(AiProvider.anthropic),
                ),
                const SizedBox(height: 12),
                Text(
                  'API keys are stored on-device in the Android Keystore.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
    if (!mounted) return;
    setState(() {
      _monthEndReminderEnabled = enabled;
      _reminderLoading = false;
    });
  }
}
