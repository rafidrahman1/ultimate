import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/router.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/prompts/prompt_template_sections.dart';

class PromptsScreen extends ConsumerWidget {
  const PromptsScreen({super.key});

  String _rulesPreview(PromptConfig config) {
    final income = config.analysisMonthlyIncomeBdt.isEmpty
        ? '{{monthlyIncomeBdt}}'
        : config.analysisMonthlyIncomeBdt;
    return PromptTemplateSections.rulesForAnalysis.replaceAll(
      '{{monthlyIncomeBdt}}',
      income,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(promptConfigProvider);

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
            },
          ),
        ],
      ),
      body: configAsync.when(
        data: (config) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Review the system prompt sent on every analysis run.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Edit your profile on Personal information. Assistant role, tone, '
                'and the sections below are fixed.',
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
              _LockedPromptSection(
                title: 'Assistant role',
                body: config.composeAssistantIdentity(),
              ),
              _LockedPromptSection(
                title: 'Tone and strictness',
                body: config.composeToneInstruction(),
              ),
              _LockedPromptSection(
                title: 'Focus instructions',
                body: config.focus,
              ),
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
