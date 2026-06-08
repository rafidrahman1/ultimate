import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_kind.dart';
import 'package:personal/features/analysis/analysis_launcher.dart';
import 'package:personal/features/results/analysis_service.dart';

/// Shows monthly insights vs progress review; runs the chosen analysis flow.
Future<void> showAnalyzeOptionsDialog({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final runState = ref.read(analysisRunProvider);
  if (runState.isRunning) return;

  final checklistSource = resolveChecklistSource(ref);

  final choice = await showDialog<AnalysisKind>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);

      return AlertDialog(
        title: const Text('Analyze'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnalyzeOptionTile(
              icon: Icons.analytics_outlined,
              title: AnalysisKind.monthlyInsights.displayName,
              subtitle:
                  'Analyze current-month data and generate next-month checklist.',
              onTap: () =>
                  Navigator.pop(dialogContext, AnalysisKind.monthlyInsights),
            ),
            const SizedBox(height: 8),
            _AnalyzeOptionTile(
              icon: Icons.trending_up_outlined,
              title: AnalysisKind.progressReview.displayName,
              subtitle: checklistSource == null
                  ? 'Run monthly insights first to generate a checklist.'
                  : 'Compare checklist targets against current-month data.',
              enabled: checklistSource != null,
              onTap: checklistSource == null
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        AnalysisKind.progressReview,
                      ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    },
  );

  if (choice == null || !context.mounted) return;

  switch (choice) {
    case AnalysisKind.monthlyInsights:
      await launchMonthlyInsightsAnalysis(context, ref);
    case AnalysisKind.progressReview:
      await launchProgressReviewAnalysis(context, ref);
  }
}

class _AnalyzeOptionTile extends StatelessWidget {
  const _AnalyzeOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: enabled
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: enabled
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? null
                            : colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: enabled
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
