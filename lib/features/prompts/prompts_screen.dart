import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/error_display.dart';
import 'package:personal/app/router.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/prompts/prompt_template_sections.dart';
import 'package:personal/core/theme/app_theme.dart';

class PromptsScreen extends ConsumerWidget {
  const PromptsScreen({super.key});

  String _rulesPreview(PromptConfig config) => config.composeRulesForAnalysis();

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
          final sections = <(String, String)>[
            ('Assistant role', config.composeAssistantIdentity()),
            ('Tone and strictness', config.composeToneInstruction()),
            ('Focus instructions', config.focus),
            ('Rules for analysis', _rulesPreview(config)),
            (
              'Data to analyze',
              '${PromptTemplateSections.focusHeader}\n\n{{focus}}\n\n${PromptTemplateSections.dataToAnalyze}',
            ),
            ('Output format', PromptTemplateSections.outputFormat),
          ];

          return ContentWidth(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screen),
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
                AppCard(
                  tier: config.isPersonalInfoComplete
                      ? AppCardTier.raised
                      : AppCardTier.hero,
                  accent: Theme.of(context).colorScheme.error,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.personalInformation,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        config.isPersonalInfoComplete
                            ? Icons.check_circle_outline
                            : Icons.person_outline,
                        color: config.isPersonalInfoComplete
                            ? context.palette.accent
                            : context.palette.warning,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personal information',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              config.isPersonalInfoComplete
                                  ? 'Profile complete — income, goals, and lifestyle'
                                  : '${config.missingPersonalInfoLabels.length} fields still needed for analysis',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: context.palette.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: [
                            for (final section in sections)
                              '## ${section.$1}\n${section.$2}',
                          ].join('\n\n'),
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Full prompt copied')),
                      );
                    },
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('Copy full prompt'),
                  ),
                ),
                const SizedBox(height: 8),
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
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Could not load prompt settings',
          subtitle: humanizeError(error),
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
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              'Read only',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            trailing: Icon(
              Icons.lock_outline,
              size: 18,
              color: palette.textMuted,
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.canvas,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  border: Border.all(color: palette.border),
                ),
                child: SelectableText(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
