import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/features/results/analysis_service.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/status_message.dart';

final monthlyAnalysisPromptPreviewProvider =
    FutureProvider.autoDispose<MonthlyAnalysisPromptPreview>((ref) {
  return buildMonthlyAnalysisPromptPreview(ref);
});

class AnalysisPromptScreen extends ConsumerWidget {
  const AnalysisPromptScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promptAsync = ref.watch(monthlyAnalysisPromptPreviewProvider);
    final accent = AppSemanticColors.prompt(context);

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Prompt',
        showBack: true,
        extraActions: [
          AppBarCircularAction(
            icon: Icons.copy_outlined,
            onPressed: promptAsync.maybeWhen(
              data: (preview) => () {
                Clipboard.setData(ClipboardData(text: preview.fullText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prompt copied')),
                );
              },
              orElse: () => null,
            ),
          ),
        ],
      ),
      body: promptAsync.when(
        data: (preview) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Everything sent to the model for a monthly insights run with '
              'all data sources.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            _PromptSection(
              title: 'System instruction',
              subtitle: 'Personal information, tone, and baselines',
              body: preview.systemInstruction,
              accent: accent,
            ),
            const SizedBox(height: 16),
            _PromptSection(
              title: 'Instructions',
              subtitle: 'Rules, focus, and output format',
              body: preview.instructions,
              accent: accent,
            ),
            const SizedBox(height: 16),
            _PromptSection(
              title: 'Data to analyze',
              subtitle: 'Derived metrics and imported data from all sources',
              body: preview.dataToAnalyze,
              accent: accent,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Could not build prompt',
          subtitle: error.toString(),
        ),
      ),
    );
  }
}

class _PromptSection extends StatelessWidget {
  const _PromptSection({
    required this.title,
    required this.body,
    required this.accent,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
            ),
          ),
          child: SelectableText(
            body,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}
