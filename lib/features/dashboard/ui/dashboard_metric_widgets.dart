part of 'dashboard_charts.dart';

/// Key figures as small tinted tiles. With [vertical] they stack as
/// label/value rows (used beside a [RingGauge]).
class DashboardMetricRow extends StatelessWidget {
  const DashboardMetricRow({
    super.key,
    required this.metrics,
    this.vertical = false,
  });

  final List<({String label, String value, Color color})> metrics;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    if (vertical) {
      return Column(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0) Divider(height: AppSpacing.lg, color: palette.border),
            MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      metrics[i].label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: palette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        metrics[i].value,
                        maxLines: 1,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: metrics[i].color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    // Tiles are single-line, so they match in height without stretching
    // (stretch needs a bounded height, which a card's Column doesn't give).
    return Row(
      children: [
        for (var i = 0; i < metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: MergeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: metrics[i].color.withValues(alpha: AppOpacity.subtle),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metrics[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        metrics[i].value,
                        maxLines: 1,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: metrics[i].color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A percentage ring with its label, followed by supporting metrics.
/// Falls back to a plain metric row when [percent] is null.
class DashboardLeadRow extends StatelessWidget {
  const DashboardLeadRow({
    super.key,
    required this.percent,
    required this.ringLabel,
    required this.ringColor,
    required this.metrics,
  });

  final double? percent;
  final String ringLabel;
  final Color ringColor;
  final List<({String label, String value, Color color})> metrics;

  @override
  Widget build(BuildContext context) {
    final value = percent;
    if (value == null) return DashboardMetricRow(metrics: metrics);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RingGauge(percent: value, color: ringColor, label: ringLabel),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: DashboardMetricRow(metrics: metrics, vertical: true)),
      ],
    );
  }
}

class DashboardStableMonthCard extends StatelessWidget {
  const DashboardStableMonthCard({super.key, required this.section});

  final DashboardStableMonthSection section;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final accent = !section.canEvaluate
        ? palette.textMuted
        : section.isStable
        ? AppSemanticColors.health(context)
        : palette.warning;
    final statusLabel = !section.canEvaluate
        ? 'Needs health + expenses'
        : section.isStable
        ? 'Stable month'
        : 'Unstable month';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                section.isStable && section.canEvaluate
                    ? Icons.verified_rounded
                    : Icons.fact_check_outlined,
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Healthy month detection',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (section.canEvaluate) ...[
            const SizedBox(height: 16),
            DashboardMetricRow(
              metrics: [
                (
                  label: 'Short nights',
                  value: '${section.shortSleepNights}',
                  color: accent,
                ),
                (
                  label: 'Sleep debt',
                  value: '${section.sleepDebtHours.toStringAsFixed(1)} h',
                  color: accent,
                ),
                (
                  label: 'Top category',
                  value: section.largestCategoryName ?? '—',
                  color: AppSemanticColors.expenses(context),
                ),
              ],
            ),
            if (section.hasSevereAnomalyCluster &&
                section.severeClusterLabel != null) ...[
              const SizedBox(height: 12),
              Text(
                'Severe cluster: ${section.severeClusterLabel}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

IconData _iconForDomain(String iconName) {
  return switch (iconName) {
    'health' => Icons.monitor_heart_outlined,
    'expenses' => Icons.account_balance_wallet_outlined,
    'location' => Icons.route_outlined,
    'gaming' => Icons.sports_esports_outlined,
    'calendar' => Icons.calendar_month_outlined,
    _ => Icons.insights_outlined,
  };
}

/// Entry animation length for charts; instant when the system asks for
/// reduced motion.
Duration _chartDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 650);
