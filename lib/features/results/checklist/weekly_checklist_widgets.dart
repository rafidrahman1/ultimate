part of 'weekly_checklist_panel.dart';

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.monthLabel,
    required this.done,
    required this.total,
    required this.streak,
  });

  final String monthLabel;
  final int done;
  final int total;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final fraction = total == 0 ? 0.0 : done / total;

    return Semantics(
      label:
          '$monthLabel plan: $done of $total actions done'
          '${streak > 0 ? ', $streak week streak' : ''}',
      excludeSemantics: true,
      child: AppCard(
        tier: AppCardTier.hero,
        accent: palette.statusGood,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MONTH PROGRESS', style: context.sectionLabel),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${(fraction * 100).round()}%',
                    style: context.statDisplay.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$done of $total actions',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (streak > 0)
              Column(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: palette.warning,
                    size: 28,
                  ),
                  Text(
                    '$streak ${streak == 1 ? 'week' : 'weeks'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text('streak', style: theme.textTheme.labelSmall),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekPillBar extends StatelessWidget {
  const _WeekPillBar({
    required this.weekCount,
    required this.selectedIndex,
    required this.currentIndex,
    required this.rangeLabelFor,
    required this.progressFor,
    required this.onSelected,
  });

  final int weekCount;
  final int selectedIndex;
  final int? currentIndex;
  final String Function(int index) rangeLabelFor;
  final ({int done, int total}) Function(int index) progressFor;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < weekCount; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _WeekPill(
              weekLabel: 'Week ${i + 1}',
              rangeLabel: rangeLabelFor(i),
              progress: progressFor(i),
              isCurrent: i == currentIndex,
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekPill extends StatelessWidget {
  const _WeekPill({
    required this.weekLabel,
    required this.rangeLabel,
    required this.progress,
    required this.isCurrent,
    required this.selected,
    required this.onTap,
  });

  final String weekLabel;
  final String rangeLabel;
  final ({int done, int total}) progress;
  final bool isCurrent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.palette.accent;

    return Semantics(
      button: true,
      selected: selected,
      label:
          '$weekLabel${isCurrent ? ', this week' : ''}'
          '${rangeLabel.isEmpty ? '' : ', $rangeLabel'}'
          '${progress.total > 0 ? ', ${progress.done} of ${progress.total} done' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.cardLarge),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minWidth: 132),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.18)
                  : context.palette.cardElevated,
              borderRadius: BorderRadius.circular(AppRadii.cardLarge),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.55)
                    : context.palette.border,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCurrent) ...[
                  Text(
                    'THIS WEEK',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  weekLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: selected ? accent : context.palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (rangeLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    rangeLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? accent.withValues(alpha: 0.9)
                          : context.palette.textMuted,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
                if (progress.total > 0) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 96,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: LinearProgressIndicator(
                        value: progress.done / progress.total,
                        minHeight: 4,
                        color: context.palette.statusGood,
                        backgroundColor: context.palette.border,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${progress.done}/${progress.total}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: context.palette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekThemeChip extends StatelessWidget {
  const _WeekThemeChip({required this.theme});

  final String theme;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: context.palette.border),
        ),
        child: Text(
          'Theme: $theme',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _WeekProgressBar extends StatelessWidget {
  const _WeekProgressBar({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final fraction = total == 0 ? 0.0 : done / total;

    return Semantics(
      label: '$done of $total done this week',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (total > 0 && done >= total) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: palette.statusGood,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                total > 0 && done >= total
                    ? 'Week complete'
                    : '$done of $total done',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${(fraction * 100).round()}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: palette.statusGood,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                color: palette.statusGood,
                backgroundColor: palette.border,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
