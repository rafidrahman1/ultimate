import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../widgets/app_screen_app_bar.dart';
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
  bool _dirty = false;

  @override
  void dispose() {
    _assistantIdentityController.dispose();
    _toneController.dispose();
    super.dispose();
  }

  String _rulesPreview(PromptConfig config) {
    final income = config.monthlyIncomeBdt.trim().isEmpty
        ? '{{monthlyIncomeBdt}}'
        : config.monthlyIncomeBdt.trim();
    return PromptTemplateSections.rulesForAnalysis.replaceAll(
      '{{monthlyIncomeBdt}}',
      income,
    );
  }

  void _syncFromConfig(PromptConfig config) {
    _assistantIdentityController.text = config.assistantIdentity;
    _toneController.text = config.toneInstruction;
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
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'System Prompt',
        extraActions: [
          AppBarCircularAction(
            icon: Icons.restart_alt,
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
                'Customize how the assistant speaks and analyzes.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Set your personal context below, then customize assistant tone and role. '
                'Both are sent on every analysis run.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: Icon(
                    config.isPersonalInfoComplete
                        ? Icons.check_circle_outline
                        : Icons.person_outline,
                    color: config.isPersonalInfoComplete
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                  title: const Text('Personal information'),
                  subtitle: Text(
                    config.isPersonalInfoComplete
                        ? 'Profile complete — income, goals, and lifestyle'
                        : '${config.missingPersonalInfoLabels.length} fields still needed for analysis',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.personalInformation),
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
              _LockedPromptSection(
                title: 'Focus instructions',
                body: config.focus,
              ),
              const SizedBox(height: 4),
              _LockedPromptSection(
                title: 'Rules for analysis',
                body: _rulesPreview(config),
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
                  final next = config.copyWith(
                    assistantIdentity: _assistantIdentityController.text.trim(),
                    toneInstruction: _toneController.text.trim(),
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
