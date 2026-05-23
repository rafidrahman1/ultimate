import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/status_message.dart';
import 'ai_settings_service.dart';

class GeneralSettingsScreen extends ConsumerStatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  ConsumerState<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends ConsumerState<GeneralSettingsScreen> {
  final _openAiKeyController = TextEditingController();
  final _openAiModelController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  final _geminiModelController = TextEditingController();

  AiProvider _provider = AiProvider.openai;
  bool _enableApiCalls = true;
  bool _dirty = false;
  bool _initialized = false;

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

    ref.listen(aiSettingsProvider, (_, next) {
      final value = next.valueOrNull;
      if (value == null || _dirty) return;
      _loadFromSettings(value);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('General settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset defaults',
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable AI API calls'),
                subtitle: const Text('Turn off to use local fallback insights only.'),
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
                Text(
                  'OpenAI',
                  style: Theme.of(context).textTheme.titleMedium,
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
                Text(
                  'Gemini',
                  style: Theme.of(context).textTheme.titleMedium,
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

                  if (_enableApiCalls && _provider == AiProvider.openai && openAiKey.isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('OpenAI API key is required')),
                    );
                    return;
                  }
                  if (_enableApiCalls && _provider == AiProvider.gemini && geminiKey.isEmpty) {
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

  void _loadFromSettings(AiSettings value) {
    _provider = value.provider;
    _enableApiCalls = value.enableApiCalls;
    _openAiKeyController.text = value.openAiApiKey;
    _openAiModelController.text = value.openAiModel;
    _geminiKeyController.text = value.geminiApiKey;
    _geminiModelController.text = value.geminiModel;
  }
}
