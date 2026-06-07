import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/analysis_month_settings_service.dart';
import '../../core/month_end_analysis_notification_service.dart';
import '../health/health_service.dart';
import '../../widgets/app_screen_app_bar.dart';
import '../../widgets/month_picker_dialog.dart';
import '../../widgets/status_message.dart';
import 'ai_settings_service.dart';

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
  bool _weekEndChecklistReminderEnabled = true;
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
    final healthAuthAsync = ref.watch(healthAuthorizationProvider);
    final analysisMonth = ref.watch(selectedAnalysisMonthProvider);
    final analysisPeriod = ref.watch(analysisPeriodProvider);
    final monthLabel = DateFormat('MMMM yyyy').format(analysisMonth);

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
              Text(
                'Analysis month',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Health, expenses, location, and game activity show only this month. '
                'Calendar includes this month and ${analysisPeriod.checklistMonthLabel} '
                'for planning.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range_outlined),
                title: Text(monthLabel),
                subtitle: Text('Data range: ${analysisPeriod.dataRangeLabel}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickAnalysisMonth(context, analysisMonth),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Month-end analysis reminder'),
                subtitle: Text(
                  _reminderLoading
                      ? 'Loading reminder preference...'
                      : 'Get a notification at month end to analyze next month.',
                ),
                value: _monthEndReminderEnabled,
                onChanged: _reminderLoading
                    ? null
                    : (enabled) async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _monthEndReminderEnabled = enabled);
                        await MonthEndAnalysisNotificationService.setReminderEnabled(
                          enabled,
                        );
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
                      },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Week-end checklist reminder'),
                subtitle: Text(
                  _reminderLoading
                      ? 'Loading reminder preference...'
                      : 'Get notified at week end if checklist items are still unchecked.',
                ),
                value: _weekEndChecklistReminderEnabled,
                onChanged: _reminderLoading
                    ? null
                    : (enabled) async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(
                          () => _weekEndChecklistReminderEnabled = enabled,
                        );
                        await MonthEndAnalysisNotificationService.setWeekEndChecklistReminderEnabled(
                          enabled,
                        );
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              enabled
                                  ? 'Week-end checklist reminder enabled'
                                  : 'Week-end checklist reminder disabled',
                            ),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: healthAuthAsync.when(
                    data: (isAuthorized) => Icon(
                      isAuthorized
                          ? Icons.check_circle_outline
                          : Icons.health_and_safety_outlined,
                      color: isAuthorized
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    loading: () => const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  title: const Text('Health'),
                  subtitle: healthAuthAsync.when(
                    data: (isAuthorized) => Text(
                      isAuthorized
                          ? 'Connected — sync and permissions'
                          : 'Authorization required for steps and sleep',
                    ),
                    loading: () => const Text('Checking Health Connect...'),
                    error: (_, __) =>
                        const Text('Could not check Health Connect status'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.healthSettings),
                ),
              ),
              const Divider(height: 32),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable AI API calls'),
                subtitle: const Text(
                  'Turn off to use local fallback insights only.',
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
                style: Theme.of(context).textTheme.labelLarge,
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
                  final value = selection.first;
                  setState(() {
                    _provider = value;
                    _dirty = true;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_provider == AiProvider.openai) ...[
                Text('OpenAI', style: Theme.of(context).textTheme.titleMedium),
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
                const SizedBox(height: 8),
                TextField(
                  controller: _openAiModelController,
                  decoration: const InputDecoration(
                    labelText: 'OpenAI model',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
              ] else ...[
                Text('Gemini', style: Theme.of(context).textTheme.titleMedium),
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
                const SizedBox(height: 8),
                TextField(
                  controller: _geminiModelController,
                  decoration: const InputDecoration(
                    labelText: 'Gemini model',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final openAiKey = _openAiKeyController.text.trim();
                  final openAiModel = _openAiModelController.text.trim();
                  final geminiKey = _geminiKeyController.text.trim();
                  final geminiModel = _geminiModelController.text.trim();

                  if (_enableApiCalls &&
                      _provider == AiProvider.openai &&
                      openAiKey.isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('OpenAI API key is required'),
                      ),
                    );
                    return;
                  }
                  if (_enableApiCalls &&
                      _provider == AiProvider.gemini &&
                      geminiKey.isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Gemini API key is required'),
                      ),
                    );
                    return;
                  }

                  final next = AiSettings(
                    provider: _provider,
                    openAiApiKey: _provider == AiProvider.openai
                        ? openAiKey
                        : '',
                    openAiModel: openAiModel.isEmpty
                        ? AiSettings.initial().openAiModel
                        : openAiModel,
                    geminiApiKey: _provider == AiProvider.gemini
                        ? geminiKey
                        : '',
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
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save settings'),
              ),
              const SizedBox(height: 12),
              Text(
                'API keys are stored on-device using app preferences.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Future<void> _pickAnalysisMonth(
    BuildContext context,
    DateTime currentMonth,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showMonthPicker(
      context: context,
      initialDate: currentMonth,
      firstDate: DateTime(2020, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12),
      helpText: 'Choose analysis month',
    );
    if (picked == null || !mounted) return;
    await ref.read(selectedAnalysisMonthProvider.notifier).setMonth(picked);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Analysis month set to ${DateFormat('MMMM yyyy').format(picked)}',
        ),
      ),
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
    final weekEndEnabled =
        await MonthEndAnalysisNotificationService.isWeekEndChecklistReminderEnabled();
    if (!mounted) return;
    setState(() {
      _monthEndReminderEnabled = enabled;
      _weekEndChecklistReminderEnabled = weekEndEnabled;
      _reminderLoading = false;
    });
  }
}
