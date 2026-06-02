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
  final _assistantIdentityController = TextEditingController();
  final _toneController = TextEditingController();
  final _professionController = TextEditingController();
  final _incomeController = TextEditingController();
  final _financialController = TextEditingController();
  final _fitnessController = TextEditingController();
  final _lifestyleController = TextEditingController();
  final _decisionSupportController = TextEditingController();
  bool _dirty = false;

  @override
  void dispose() {
    _assistantIdentityController.dispose();
    _toneController.dispose();
    _professionController.dispose();
    _incomeController.dispose();
    _financialController.dispose();
    _fitnessController.dispose();
    _lifestyleController.dispose();
    _decisionSupportController.dispose();
    super.dispose();
  }

  String _rulesPreview() {
    final income = _incomeController.text.trim().isEmpty
        ? PromptConfig.initial().monthlyIncomeBdt
        : _incomeController.text.trim();
    return PromptTemplateSections.rulesForAnalysis.replaceAll(
      '{{monthlyIncomeBdt}}',
      income,
    );
  }

  void _syncFromConfig(PromptConfig config) {
    _assistantIdentityController.text = config.assistantIdentity;
    _toneController.text = config.toneInstruction;
    _professionController.text = config.professionAndSchedule;
    _incomeController.text = config.monthlyIncomeBdt;
    _financialController.text = config.financialInstruction;
    _fitnessController.text = config.fitnessGoal;
    _lifestyleController.text = config.householdLifestyle;
    _decisionSupportController.text = config.decisionSupportRule;
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
        title: const Text('System Prompt'),
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
          if (_assistantIdentityController.text.isEmpty && !_dirty) {
            _syncFromConfig(config);
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Personalize the system prompt with guided fields.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Fill these sections once. They are sent as system instructions on every analysis run.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _assistantIdentityController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Assistant role',
                  hintText: 'Who the assistant is for you',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _toneController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Tone and strictness',
                  hintText: 'How direct or strict responses should be',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _professionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Profession and schedule',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _incomeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly income (BDT)',
                  hintText: 'e.g. 35000',
                  border: OutlineInputBorder(),
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
                  hintText: 'Budget constraints and spending expectations',
                  border: OutlineInputBorder(),
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
                  hintText: 'Body goal, activity target, recovery requirements',
                  border: OutlineInputBorder(),
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
                  hintText: 'Personal context that affects recommendations',
                  border: OutlineInputBorder(),
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
                  hintText: 'How Buy/Skip or other verdicts should be handled',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: 16),
              _LockedPromptSection(
                title: 'Focus instructions',
                body: config.focus,
              ),
              const SizedBox(height: 4),
              _LockedPromptSection(
                title: 'Rules for analysis',
                body: _rulesPreview(),
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
                    assistantIdentity: _assistantIdentityController.text.trim(),
                    toneInstruction: _toneController.text.trim(),
                    professionAndSchedule: _professionController.text.trim(),
                    monthlyIncomeBdt: _incomeController.text.trim(),
                    financialInstruction: _financialController.text.trim(),
                    fitnessGoal: _fitnessController.text.trim(),
                    householdLifestyle: _lifestyleController.text.trim(),
                    decisionSupportRule: _decisionSupportController.text.trim(),
                    focus: config.focus,
                  );
                  await ref.read(promptConfigProvider.notifier).save(next);
                  if (!mounted) return;
                  setState(() => _dirty = false);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('System prompt saved')),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save system prompt'),
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
  const _LockedPromptSection({required this.title, required this.body});

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
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
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
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
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
