part of 'prediction_list.dart';

String _semantics(PredictionCardData d) =>
    '${d.label}: ${d.figure ?? d.headline}. ${d.figureCaption ?? d.detail}'
    '${d.confidence == null ? '' : '. ${d.confidence!.label} confidence'}'
    '${d.aiRefined ? '. Refined with AI' : ''}';

/// Icon in a soft accent-tinted rounded square.
class _IconBadge extends StatelessWidget {
  const _IconBadge(this.data, {this.dimension = 44});

  final PredictionCardData data;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: data.accent.withValues(alpha: AppOpacity.strong),
        borderRadius: BorderRadius.circular(AppRadii.cardLarge),
      ),
      child: SizedBox.square(
        dimension: dimension,
        child: Icon(data.icon, size: dimension * 0.5, color: data.accent),
      ),
    );
  }
}

/// Small pill flagging urgency, or the AI sparkle when refined.
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.data);

  final PredictionCardData data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final urgent = data.urgency != PredictionUrgency.normal;
    if (!urgent && !data.aiRefined) return const SizedBox.shrink();
    final color = urgent ? data.accent : palette.accent;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.medium),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            urgent ? Icons.bolt_rounded : Icons.auto_awesome_rounded,
            size: 12,
            color: color,
          ),
          if (urgent) ...[
            const SizedBox(width: 2),
            Text(
              data.urgency == PredictionUrgency.critical ? 'Urgent' : 'Soon',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact prediction card for the two-column grid: icon box beside the
/// title, confidence pill, headline and short detail, with an illustration
/// in the bottom-right corner.
class PredictionTile extends StatelessWidget {
  const PredictionTile({
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
    final hasVisual =
        data.visual != PredictionVisual.none &&
        (data.visual != PredictionVisual.gauge || data.visualValue != null) &&
        (data.visual != PredictionVisual.dateBadge || data.date != null);
    final pill = data.confidence == null
        ? _StatusPill(data)
        : PredictionConfidencePill(confidence: data.confidence!, compact: true);
    final title = Text(
      data.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
    const radius = AppRadii.cardLarge + 6;

    return Semantics(
      button: true,
      label: _semantics(data),
      excludeSemantics: true,
      child: Material(
        color: Color.alphaBlend(
          data.accent.withValues(alpha: 0.07),
          palette.card,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: data.accent.withValues(alpha: 0.28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IconBadge(data, dimension: 52),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: title),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 130,
                                  ),
                                  child: pill,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (busy)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  data.headline,
                                  maxLines: 1,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 2),
                            Padding(
                              padding: EdgeInsets.only(
                                right: hasVisual ? 64 : 0,
                              ),
                              child: Text(
                                data.shortDetail ?? data.detail,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: palette.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasVisual)
                  Positioned(
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: PredictionVisualView(data: data, size: 56),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of the upcoming list: icon, title and detail, date, ⋮ menu.
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({
    required this.data,
    required this.onTap,
    required this.busy,
    this.onHide,
  });

  final PredictionCardData data;
  final VoidCallback onTap;
  final bool busy;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final trailing = data.date != null
        ? DateFormat('MMM d, y').format(data.date!)
        : data.headline;
    return Semantics(
      container: true,
      label: _semantics(data),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            top: AppSpacing.md,
            bottom: AppSpacing.md,
          ),
          child: Row(
            children: [
              _IconBadge(data, dimension: 52),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      data.shortDetail ?? data.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (busy)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    trailing,
                    maxLines: 2,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: Icon(Icons.more_vert_rounded, color: palette.textMuted),
                onSelected: (value) =>
                    value == 'hide' ? onHide?.call() : onTap(),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: Text('Open details'),
                  ),
                  if (onHide != null)
                    const PopupMenuItem(
                      value: 'hide',
                      child: Text('Hide this prediction'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
