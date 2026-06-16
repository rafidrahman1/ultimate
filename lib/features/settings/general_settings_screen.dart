import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_reports_storage.dart';
import 'package:personal/features/analysis/month_end_analysis_notification_service.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
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

    return Scaffold(
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
            padding: const EdgeInsets.all(20),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                      const SizedBox(height: 8),
                      Text(
                        'Preferred provider',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<AiProvider>(
                        segments: const [
                          ButtonSegment(
                            value: AiProvider.openai,
                            label: Text('OpenAI'),
                            icon: Icon(Icons.auto_awesome),
                          ),
                          ButtonSegment(
                            value: AiProvider.gemini,
                            label: Text('Gemini'),
                            icon: Icon(Icons.bolt),
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
                      const SizedBox(height: 16),
                      Text(
                        'OpenAI',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _openAiKeyController,
                        decoration: const InputDecoration(
                          labelText: 'OpenAI API key',
                          hintText: 'sk-...',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _openAiModelController,
                        decoration: const InputDecoration(
                          labelText: 'OpenAI model',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Gemini',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _geminiKeyController,
                        decoration: const InputDecoration(
                          labelText: 'Gemini API key',
                          hintText: 'AIza...',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _geminiModelController,
                        decoration: const InputDecoration(
                          labelText: 'Gemini model',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _dirty = true),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _dirty ? () => _saveAiSettings() : null,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save AI settings'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'API keys are stored on-device using app preferences.',
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
          subtitle: error.toString(),
        ),
      ),
    );
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
      enableApiCalls: _enableApiCalls,
    );
    await ref.read(aiSettingsProvider.notifier).save(next);
    if (!mounted) return;
    setState(() => _dirty = false);
    messenger.showSnackBar(
      const SnackBar(content: Text('AI settings saved')),
    );
  }

  void _loadFromSettings(AiSettings value) {
    _provider = value.provider;
    _enableApiCalls = value.enableApiCalls;
    _openAiKeyController.text = value.openAiApiKey;
    _openAiModelController.text = value.openAiModel;
    _geminiKeyController.text = value.geminiApiKey;
    _geminiModelController.text = value.geminiModel;
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
