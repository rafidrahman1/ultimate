part of 'prediction_list.dart';

/// The lead prediction: figure, caption, trend line, progress bar and the
/// boxed "Why this estimate?".
class PredictionHero extends StatelessWidget {
  const PredictionHero({
    super.key,
    required this.data,
    required this.onTap,
    this.busy = false,
  });

  final PredictionCardData data;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final figure = data.figure ?? data.headline;
    final caption = data.figureCaption ?? data.shortDetail ?? data.detail;
    final hasSeries = data.series.length >= 2;

    return Semantics(
      container: true,
      label: _semantics(data),
      child: AppCard(
        tier: AppCardTier.hero,
        accent: data.accent,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconBadge(data, dimension: 60),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Builder(
                          builder: (context) {
                            final label = Text(
                              data.label.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.sectionLabel,
                            );
                            final badge = data.confidence != null
                                ? ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 170,
                                    ),
                                    child: PredictionConfidencePill(
                                      confidence: data.confidence!,
                                      compact:
                                          MediaQuery.sizeOf(context).width <
                                          400,
                                    ),
                                  )
                                : _StatusPill(data);
                            // Very large text: the pill drops under the title,
                            // still at the right.
                            if (MediaQuery.textScalerOf(context).scale(1) >
                                1.5) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  label,
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: badge,
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: label),
                                const SizedBox(width: AppSpacing.sm),
                                badge,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (busy)
                                    const SizedBox(
                                      height: 36,
                                      width: 36,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                      ),
                                    )
                                  else
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        figure,
                                        maxLines: 1,
                                        style: theme.textTheme.displaySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: data.accent,
                                              height: 1.05,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    caption,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: palette.textSecondary,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasSeries) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Sparkline(
                                values: data.series,
                                color: data.accent,
                                width: 88,
                                height: 52,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (data.progress != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: data.progress!),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 12,
                    color: data.accent,
                    backgroundColor: palette.border,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.progressLeft ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      data.progressRight ?? '',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (data.facts.isNotEmpty || data.confidence != null) ...[
              const SizedBox(height: AppSpacing.md),
              PredictionExplanation(data: data),
            ],
          ],
        ),
      ),
    );
  }
}
