part of 'progress_review_dashboard.dart';

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.data});

  final ProgressReviewViewData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final color = reviewStatusColor(
      context,
      reviewStatusFromScore(data.overallScore),
    );

    return AppCard(
      tier: AppCardTier.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            reviewMonthTitle(data.title),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: ScoreRingChart(
              score: data.overallScore,
              size: 148,
              stroke: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            reviewVerdict(data.overallScore),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SummaryCallout(summary: data.summary),
        ],
      ),
    );
  }
}

class _SummaryCallout extends StatefulWidget {
  const _SummaryCallout({required this.summary});

  final String summary;

  @override
  State<_SummaryCallout> createState() => _SummaryCalloutState();
}

class _SummaryCalloutState extends State<_SummaryCallout> {
  static const _collapsedLines = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      height: 1.5,
      color: palette.textSecondary,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.cardElevated,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadii.cardLarge),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final overflows = (TextPainter(
            text: TextSpan(text: widget.summary, style: style),
            maxLines: _collapsedLines,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth)).didExceedMaxLines;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'In short',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: palette.accent,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: Text(
                  widget.summary,
                  style: style,
                  maxLines: _expanded ? null : _collapsedLines,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                ),
              ),
              if (overflows)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(_expanded ? 'Show less' : 'Read more'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Domain breakdown cards
// ---------------------------------------------------------------------------
