part of 'app_drawer.dart';

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Row(
        children: [Expanded(child: Text(title, style: context.sectionLabel))],
      ),
    );
  }
}

/// Setup summary derived from the live [SettingsStatus]: a count of areas
/// needing attention and a bar showing how many of them are fine.
class _DrawerSetupProgress extends StatelessWidget {
  const _DrawerSetupProgress({required this.status});

  final SettingsStatus status;

  static const _areas = 4;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final toFix = status.warningCount;
    final done = toFix == 0;
    final color = done ? palette.statusGood : palette.warning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Semantics(
        label: done
            ? 'Setup complete'
            : 'Setup: $toFix of $_areas areas need attention',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  done
                      ? Icons.check_circle_outline_rounded
                      : Icons.tune_rounded,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    done ? 'SETUP · ALL SET' : 'SETUP · $toFix TO FIX',
                    style: context.sectionLabel.copyWith(color: color),
                  ),
                ),
                Text(
                  '${_areas - toFix}/$_areas',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: (_areas - toFix) / _areas),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  color: color,
                  backgroundColor: palette.border,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerAnalysisMonthCard extends StatelessWidget {
  const _DrawerAnalysisMonthCard({
    required this.monthLabel,
    required this.isCurrentMonth,
    required this.onTap,
  });

  final String monthLabel;
  final bool isCurrentMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final label = isCurrentMonth ? 'Current month' : 'Selected month';

    return Semantics(
      button: true,
      label: '$label, $monthLabel. Change month',
      excludeSemantics: true,
      child: Material(
        color: palette.accent.withValues(alpha: AppOpacity.subtle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.cardLarge),
          side: BorderSide(color: palette.accent.withValues(alpha: 0.25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                _DrawerIconBadge(
                  icon: Icons.calendar_month_rounded,
                  color: palette.accent,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        monthLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerNavItem extends StatelessWidget {
  const _DrawerNavItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.status,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Live state line; its tone colours the dot and text.
  final StatusLine? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final line = status;
    final tone = line?.tone;
    final accent = switch (tone) {
      StatusTone.ok => palette.statusGood,
      StatusTone.warning => palette.warning,
      _ => palette.textMuted,
    };
    final text = line?.text ?? subtitle ?? '';

    return Semantics(
      button: true,
      label:
          '$title. $text'
          '${tone == StatusTone.warning ? '. Needs attention' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            child: Row(
              children: [
                _DrawerIconBadge(icon: icon, color: palette.textSecondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (line != null && tone != StatusTone.neutral) ...[
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                              child: const SizedBox.square(dimension: 6),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tone == StatusTone.warning
                                    ? palette.warning
                                    : palette.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerIconBadge extends StatelessWidget {
  const _DrawerIconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.cardElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: context.palette.border),
      ),
      child: SizedBox.square(
        dimension: 44,
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }
}
