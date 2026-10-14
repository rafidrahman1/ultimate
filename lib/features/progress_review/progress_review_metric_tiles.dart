part of 'progress_review_dashboard.dart';

class _MetricLineTile extends StatelessWidget {
  const _MetricLineTile({required this.metric, required this.accent});

  final DomainMetricLine metric;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final flagColor = reviewStatusColor(context, ReviewStatus.warning);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: metric.flagged
            ? flagColor.withValues(alpha: AppOpacity.subtle)
            : palette.cardElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (metric.flagged) ...[
                Icon(Icons.warning_amber_rounded, size: 14, color: flagColor),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  metric.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: metric.flagged ? flagColor : palette.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textPrimary,
                height: 1.3,
              ),
              children: [
                TextSpan(
                  text: metric.actual,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: '  vs  ',
                  style: TextStyle(color: palette.textMuted),
                ),
                TextSpan(
                  text: metric.target,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBadge extends StatelessWidget {
  const _WarningBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.palette.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.report_problem_rounded, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Discrepancy matrix
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.icon,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.palette.textPrimary,
          ),
        ),
      ],
    );
  }
}

Color _domainColor(BuildContext context, String name) {
  return AppSemanticColors.forDomainName(name, context);
}

IconData _domainIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('health') || n.contains('sleep')) {
    return Icons.favorite_rounded;
  }
  if (n.contains('expense')) return Icons.account_balance_wallet_rounded;
  if (n.contains('location') || n.contains('mobility')) {
    return Icons.route_rounded;
  }
  if (n.contains('gaming') || n.contains('leisure')) {
    return Icons.sports_esports_rounded;
  }
  if (n.contains('calendar') || n.contains('schedule')) {
    return Icons.calendar_month_rounded;
  }
  return Icons.insights_rounded;
}

IconData _toneIcon(VarianceTone tone) {
  return switch (tone) {
    VarianceTone.positive => Icons.trending_down_rounded,
    VarianceTone.compliant => Icons.check_circle_rounded,
    VarianceTone.neutral => Icons.trending_flat_rounded,
    VarianceTone.negative => Icons.trending_up_rounded,
  };
}

// ---------------------------------------------------------------------------
// Score ring
// ---------------------------------------------------------------------------
