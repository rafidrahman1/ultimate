import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/status_message.dart';
import 'prompt_config_service.dart';

class PromptsScreen extends ConsumerStatefulWidget {
  const PromptsScreen({super.key});

  @override
  ConsumerState<PromptsScreen> createState() => _PromptsScreenState();
}

class _PromptsScreenState extends ConsumerState<PromptsScreen> {
  final _templateController = TextEditingController();
  final _focusController = TextEditingController();
  bool _dirty = false;

  @override
  void dispose() {
    _templateController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(promptConfigProvider);

    ref.listen(promptConfigProvider, (_, next) {
      final value = next.valueOrNull;
      if (value == null || _dirty) return;
      _templateController.text = value.template;
      _focusController.text = value.focus;
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
          if (_templateController.text.isEmpty && !_dirty) {
            _templateController.text = config.template;
            _focusController.text = config.focus;
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
                'Use placeholders: {{focus}}, {{health}}, {{expenses}}, {{commute}}, {{chat}}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
              TextField(
                controller: _templateController,
                minLines: 10,
                maxLines: 16,
                decoration: const InputDecoration(
                  labelText: 'Prompt template',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final next = PromptConfig(
                    template: _templateController.text.trim(),
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
