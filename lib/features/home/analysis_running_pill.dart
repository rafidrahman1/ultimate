import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/home/analysis_progress_sheet.dart';
import 'package:personal/features/results/analysis_service.dart';

/// Shown above the bottom nav on every tab while an analysis runs, so the
/// progress sheet can be reopened after it's swiped away.
class AnalysisRunningPill extends ConsumerWidget {
  const AnalysisRunningPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(analysisRunProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: !run.isRunning
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                0,
                AppSpacing.screen,
                AppSpacing.sm,
              ),
              child: Semantics(
                button: true,
                label:
                    'Analysis running: ${run.stage?.label ?? 'starting'}. '
                    'Show progress',
                excludeSemantics: true,
                child: Material(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => showAnalysisProgressSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              run.stage?.label ?? 'Starting analysis',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.expand_less_rounded,
                            size: 20,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
