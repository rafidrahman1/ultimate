import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/status_message.dart';
import 'prompt_config_service.dart';
import 'prompt_template_sections.dart';

class PromptsScreen extends ConsumerStatefulWidget {
  const PromptsScreen({super.key});

  @override
  ConsumerState<PromptsScreen> createState() => _PromptsScreenState();
}

class _PromptsScreenState extends ConsumerState<PromptsScreen> {
  final _preambleController = TextEditingController();
  final _focusController = TextEditingController();
  bool _dirty = false;

  @override
  void dispose() {
    _preambleController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  void _syncFromConfig(PromptConfig config) {
    _preambleController.text = config.preamble;
    _focusController.text = config.focus;
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(promptConfigProvider);

    ref.listen(promptConfigProvider, (_, next) {
      final value = next.valueOrNull;
      if (value == null || _dirty) return;
      _syncFromConfig(value);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset defaults',
            onPressed: () async {
              await ref.read(promptConfigProvider.notifier).reset();
              if (!mounted) return;
              setState(() => _dirty = false);
            },
          ),
        ],
      ),
      body: configAsync.when(
        data: (config) {
          if (_preambleController.text.isEmpty && !_dirty) {
            _syncFromConfig(config);
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Customize how your data is analyzed.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Context and focus are editable. Rules, data slots, and output format are fixed.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _preambleController,
                minLines: 8,
                maxLines: 20,
                decoration: const InputDecoration(
                  labelText: 'Context & baselines',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _focusController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Focus instructions',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 16),
              _LockedPromptSection(
                title: 'Rules for analysis',
                body: PromptTemplateSections.rulesForAnalysis,
              ),
              _LockedPromptSection(
                title: 'Data to analyze',
                body:
                    '${PromptTemplateSections.focusHeader}\n\n{{focus}}\n\n${PromptTemplateSections.dataToAnalyze}',
              ),
              _LockedPromptSection(
                title: 'Output format',
                body: PromptTemplateSections.outputFormat,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final next = PromptConfig(
                    preamble: _preambleController.text.trim(),
                    focus: _focusController.text.trim(),
                  );
                  await ref.read(promptConfigProvider.notifier).save(next);
                  if (!mounted) return;
                  setState(() => _dirty = false);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Prompt settings saved')),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save prompt'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Could not load prompt settings',
          subtitle: error.toString(),
        ),
      ),
    );
  }
}

class _LockedPromptSection extends StatelessWidget {
  const _LockedPromptSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Icon(
              Icons.lock_outline,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        subtitle: Text(
          'Read only',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: SelectableText(
              body,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
