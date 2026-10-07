part of 'personal_information_screen.dart';

/// Completeness ring plus one tappable chip per missing field.
class _CompletionHero extends StatelessWidget {
  const _CompletionHero({
    required this.draft,
    required this.isComplete,
    required this.onJump,
  });

  final PromptConfig draft;
  final bool isComplete;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final total = draft.requiredPersonalInfoKeys.length;
    final missingKeys = draft.missingPersonalInfoKeys;
    final done = total - missingKeys.length;
    final percent = total == 0 ? 0.0 : done / total * 100;

    return AppCard(
      tier: isComplete ? AppCardTier.hero : AppCardTier.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RingGauge(
                percent: percent,
                color: palette.accent,
                label: 'complete',
                size: 84,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isComplete ? 'Ready for analysis' : 'Almost there',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isComplete
                          ? 'All required fields are filled in.'
                          : '$done of $total required fields done. Analysis '
                                'stays off until the rest are filled in.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (missingKeys.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('STILL NEEDED', style: context.sectionLabel),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final key in missingKeys)
                  ActionChip(
                    label: Text(
                      PromptConfig.personalInfoFieldLabels[key] ?? key,
                    ),
                    avatar: Icon(
                      Icons.arrow_outward_rounded,
                      size: 14,
                      color: palette.warning,
                    ),
                    onPressed: () => onJump(
                      PromptConfig.basicPersonalInfoKeys.contains(key)
                          ? 'about'
                          : const {
                              'financialInstruction',
                              'fitnessGoal',
                              'householdLifestyle',
                              'decisionSupportRule',
                            }.contains(key)
                          ? 'goals'
                          : 'profession',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A form block with a tappable header that shows how much is left in it.
class _FormSection extends StatelessWidget {
  const _FormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.missing,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final IconData icon;
  final int missing;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final tone = missing > 0 ? palette.warning : palette.accent;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label:
                '$title, ${missing > 0 ? '$missing fields needed' : 'complete'}',
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: tone),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: AppOpacity.medium),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        missing > 0 ? '$missing needed' : 'Done',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tone,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
