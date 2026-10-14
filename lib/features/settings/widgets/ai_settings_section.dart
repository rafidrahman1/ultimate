import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/features/settings/widgets/ai_provider_section.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Provider choice, the API-calls switch and the per-provider key/model fields.
///
/// Stateless: the screen owns the controllers and the dirty/save logic.
class AiSettingsSection extends StatelessWidget {
  const AiSettingsSection({
    super.key,
    required this.enableApiCalls,
    required this.provider,
    required this.openAiKeyController,
    required this.openAiModelController,
    required this.geminiKeyController,
    required this.geminiModelController,
    required this.anthropicKeyController,
    required this.anthropicModelController,
    required this.onEnableApiCallsChanged,
    required this.onProviderChanged,
    required this.onChanged,
    required this.onTest,
  });

  final bool enableApiCalls;
  final AiProvider provider;
  final TextEditingController openAiKeyController;
  final TextEditingController openAiModelController;
  final TextEditingController geminiKeyController;
  final TextEditingController geminiModelController;
  final TextEditingController anthropicKeyController;
  final TextEditingController anthropicModelController;
  final ValueChanged<bool> onEnableApiCallsChanged;
  final ValueChanged<AiProvider> onProviderChanged;
  final VoidCallback onChanged;
  final Future<String?> Function(AiProvider provider) onTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                value: enableApiCalls,
                onChanged: onEnableApiCallsChanged,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Preferred provider', style: theme.textTheme.labelLarge),
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
                selected: {provider},
                onSelectionChanged: (selection) =>
                    onProviderChanged(selection.first),
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
          keyController: openAiKeyController,
          modelController: openAiModelController,
          isActive: provider == AiProvider.openai,
          onChanged: onChanged,
          onTest: () => onTest(AiProvider.openai),
        ),
        const SizedBox(height: AppSpacing.sm),
        AiProviderSection(
          title: 'Gemini',
          icon: Icons.diamond_outlined,
          keyLabel: 'Gemini API key',
          keyHint: 'AIza...',
          modelLabel: 'Gemini model',
          keyController: geminiKeyController,
          modelController: geminiModelController,
          isActive: provider == AiProvider.gemini,
          onChanged: onChanged,
          onTest: () => onTest(AiProvider.gemini),
        ),
        const SizedBox(height: AppSpacing.sm),
        AiProviderSection(
          title: 'Claude (Anthropic)',
          icon: Icons.psychology_alt_outlined,
          keyLabel: 'Anthropic API key',
          keyHint: 'sk-ant-...',
          modelLabel: 'Claude model',
          keyController: anthropicKeyController,
          modelController: anthropicModelController,
          isActive: provider == AiProvider.anthropic,
          onChanged: onChanged,
          onTest: () => onTest(AiProvider.anthropic),
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
  }
}
