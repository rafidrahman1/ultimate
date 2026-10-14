part of 'progress_review_dashboard.dart';

class _DomainCard extends StatelessWidget {
  const _DomainCard({required this.domain});

  final DomainBreakdown domain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _domainColor(context, domain.name);
    final excluded = domain.excluded;

    return AppCard(
      tier: excluded ? AppCardTier.flat : AppCardTier.raised,
      child: Opacity(
        opacity: excluded ? 0.7 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(
                      alpha: excluded ? AppOpacity.subtle : AppOpacity.medium,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: Icon(
                    _domainIcon(domain.name),
                    size: 20,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    domain.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: domain.status, excluded: excluded),
              ],
            ),
            if (excluded)
              _ExcludedBody(domain: domain)
            else
              _ScoredBody(domain: domain, accent: accent),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.excluded});

  final String status;
  final bool excluded;

  @override
  Widget build(BuildContext context) {
    final color = excluded
        ? context.palette.textMuted
        : reviewStatusColor(context, reviewStatusFromLabel(status));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.medium),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            excluded
                ? Icons.block_rounded
                : reviewStatusIcon(reviewStatusFromLabel(status)),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            reviewStatusText(status),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoredBody extends StatefulWidget {
  const _ScoredBody({required this.domain, required this.accent});

  final DomainBreakdown domain;
  final Color accent;

  @override
  State<_ScoredBody> createState() => _ScoredBodyState();
}

class _ScoredBodyState extends State<_ScoredBody> {
  /// Details open by default only when something needs the reader's attention.
  late bool _expanded =
      widget.domain.warning != null ||
      widget.domain.metrics.any((m) => m.flagged);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final domain = widget.domain;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: LinearProgressIndicator(
                  value: domain.progress,
                  minHeight: 10,
                  backgroundColor: palette.border,
                  valueColor: AlwaysStoppedAnimation<Color>(widget.accent),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${domain.score}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: widget.accent,
              ),
            ),
          ],
        ),
        if (domain.warning != null) ...[
          const SizedBox(height: 12),
          _WarningBadge(text: domain.warning!),
        ],
        if (domain.metrics.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 20,
              ),
              label: Text(_expanded ? 'Hide details' : 'Show details'),
            ),
          ),
          if (_expanded)
            ...domain.metrics.map(
              (m) => _MetricLineTile(metric: m, accent: widget.accent),
            ),
        ],
      ],
    );
  }
}

class _ExcludedBody extends StatelessWidget {
  const _ExcludedBody({required this.domain});

  final DomainBreakdown domain;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: palette.cardElevated,
            borderRadius: BorderRadius.circular(AppRadii.small),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Icon(Icons.block_rounded, size: 16, color: palette.textMuted),
              const SizedBox(width: 8),
              Text(
                'Excluded from targets',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (domain.baselineStats.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Baseline stats',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          ...domain.baselineStats.map(
            (stat) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      stat,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
