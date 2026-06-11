import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_kind.dart';
import 'package:personal/features/analysis/analysis_launcher.dart';
import 'package:personal/features/results/analysis_service.dart';
import 'package:personal/shared/navigation/expand_page_route.dart';

/// Expands the AI analyze button into a compact options card.
Future<void> showAnalyzeOptionsDialog({
  required BuildContext context,
  required WidgetRef ref,
  required BuildContext buttonContext,
}) async {
  final runState = ref.read(analysisRunProvider);
  if (runState.isRunning) return;

  final checklistSource = resolveChecklistSource(ref);
  final colorScheme = Theme.of(context).colorScheme;

  final choice = await pushExpandCardRoute<AnalysisKind>(
    buttonContext,
    backdropColor: colorScheme.surfaceContainerHighest,
    child: _AnalyzeOptionsCard(
      checklistSourceAvailable: checklistSource != null,
    ),
  );

  if (choice == null || !context.mounted) return;

  switch (choice) {
    case AnalysisKind.monthlyInsights:
      await launchMonthlyInsightsAnalysis(context, ref);
    case AnalysisKind.progressReview:
      await launchProgressReviewAnalysis(context, ref);
  }
}

class _AnalyzeOptionsCard extends StatelessWidget {
  const _AnalyzeOptionsCard({
    required this.checklistSourceAvailable,
  });

  final bool checklistSourceAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      elevation: 6,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Analyze',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _AnalyzeOptionTile(
              icon: Icons.analytics_outlined,
              title: AnalysisKind.monthlyInsights.displayName,
              subtitle:
                  'Analyze current-month data and generate next-month checklist.',
              onTap: () => Navigator.pop(
                context,
                AnalysisKind.monthlyInsights,
              ),
            ),
            const SizedBox(height: 8),
            _AnalyzeOptionTile(
              icon: Icons.trending_up_outlined,
              title: AnalysisKind.progressReview.displayName,
              subtitle: checklistSourceAvailable
                  ? 'Compare checklist targets against current-month data.'
                  : 'Run monthly insights first to generate a checklist.',
              enabled: checklistSourceAvailable,
              onTap: checklistSourceAvailable
                  ? () => Navigator.pop(
                        context,
                        AnalysisKind.progressReview,
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
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
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 22,
                color: enabled
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? null
                            : colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: enabled
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface.withValues(alpha: 0.38),
                        height: 1.35,
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
