import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/home/home_summary_providers.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Guided first-run steps; hides itself once the required ones are done.
class SetupChecklistCard extends ConsumerWidget {
  const SetupChecklistCard({super.key});

  String? _routeFor(SetupStepId id) => switch (id) {
    SetupStepId.folder => AppRoutes.generalSettings,
    SetupStepId.profile => AppRoutes.personalInformation,
    SetupStepId.ai => AppRoutes.generalSettings,
    SetupStepId.data => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = ref.watch(homeSetupStepsProvider);
    if (steps.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final status = context.statusColors;
    final doneCount = steps.where((s) => s.done).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Get set up', style: theme.textTheme.titleMedium),
                ),
                Text(
                  '$doneCount of ${steps.length}',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final step in steps)
              Semantics(
                button: _routeFor(step.id) != null && !step.done,
                label:
                    '${step.title}, ${step.done ? 'done' : 'to do'}. ${step.hint}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: step.done || _routeFor(step.id) == null
                      ? null
                      : () => Navigator.pushNamed(context, _routeFor(step.id)!),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          step.done
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 22,
                          color: step.done
                              ? status.good
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: step.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: step.done
                                      ? theme.colorScheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                              Text(step.hint, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        if (!step.done && _routeFor(step.id) != null)
                          const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
