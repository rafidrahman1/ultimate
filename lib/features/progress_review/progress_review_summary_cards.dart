part of 'progress_review_dashboard.dart';

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.data});

  final ProgressReviewViewData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return AppCard(
      tier: AppCardTier.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.cardElevated,
                        borderRadius: BorderRadius.circular(AppRadii.small),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        'System ID · ${data.id}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.textMuted,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ScoreRingChart(score: data.overallScore, size: 104, stroke: 11),
            ],
          ),
          const SizedBox(height: 18),
          _SummaryCallout(summary: data.summary),
        ],
      ),
    );
  }
}

class _SummaryCallout extends StatelessWidget {
  const _SummaryCallout({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.cardLarge),
      child: Container(
        decoration: BoxDecoration(
          color: palette.cardElevated,
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(AppRadii.cardLarge),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: palette.accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.summarize_rounded,
                            size: 16,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Core summary',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: palette.accent,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Domain breakdown cards
// ---------------------------------------------------------------------------
