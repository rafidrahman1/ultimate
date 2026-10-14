import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/predictions/prediction_cards.dart';
import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Predictions as a hero card plus a two-column tile grid: filter chips by
/// group, most urgent first, and the "All" view collapsed to stay short.
class PredictionList extends StatefulWidget {
  const PredictionList({
    super.key,
    required this.cards,
    required this.busyKeys,
    required this.onOpen,
  });

  /// Collapsed "All" view shows this many.
  static const collapsedCount = 5;

  final List<PredictionCardData> cards;
  final Set<String> busyKeys;
  final ValueChanged<PredictionCardData> onOpen;

  @override
  State<PredictionList> createState() => _PredictionListState();
}

class _PredictionListState extends State<PredictionList> {
  PredictionGroup? _group;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = [
      for (final g in PredictionGroup.values)
        if (widget.cards.any((c) => c.group == g)) g,
    ];
    // A filter whose cards vanished falls back to "All".
    final group = groups.contains(_group) ? _group : null;
    final filtered = [
      for (final c in widget.cards)
        if (group == null || c.group == group) c,
    ];
    final collapsible =
        group == null && filtered.length > PredictionList.collapsedCount + 1;
    final shown = collapsible && !_expanded
        ? filtered.take(PredictionList.collapsedCount).toList()
        : filtered;

    final hero = shown.isEmpty ? null : shown.first;
    final tiles = shown.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groups.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('All', widget.cards.length, group == null, () {
                  setState(() => _group = null);
                }),
                for (final g in groups)
                  _chip(
                    g.label,
                    widget.cards.where((c) => c.group == g).length,
                    group == g,
                    () => setState(() => _group = g),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        if (hero != null)
          PredictionHero(
            data: hero,
            busy: widget.busyKeys.contains(hero.key),
            onTap: () => widget.onOpen(hero),
          ),
        for (var i = 0; i < tiles.length; i += 2) ...[
          const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tile(tiles[i])),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: i + 1 < tiles.length
                      ? _tile(tiles[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
        if (collapsible)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded
                  ? 'Show less'
                  : 'Show ${filtered.length - shown.length} more',
              style: theme.textTheme.labelLarge,
            ),
          ),
      ],
    );
  }

  Widget _tile(PredictionCardData d) => PredictionTile(
    data: d,
    busy: widget.busyKeys.contains(d.key),
    onTap: () => widget.onOpen(d),
  );

  Widget _chip(String label, int count, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text('$label $count'),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

String _semantics(PredictionCardData d) =>
    '${d.label}: ${d.headline}. ${d.detail}'
    '${d.aiRefined ? '. Refined with AI' : ''}';

/// Icon in a soft accent-tinted rounded square.
class _IconBadge extends StatelessWidget {
  const _IconBadge(this.data, {this.size = 18});

  final PredictionCardData data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.45),
      decoration: BoxDecoration(
        color: data.accent.withValues(alpha: AppOpacity.strong),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Icon(data.icon, size: size, color: data.accent),
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

/// The lead prediction: a large tinted card with the headline figure shown big.
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
    return Semantics(
      button: true,
      label: _semantics(data),
      excludeSemantics: true,
      child: AppCard(
        tier: AppCardTier.hero,
        accent: data.accent,
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBadge(data, size: 20),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    data.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                _StatusPill(data),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (busy)
              const SizedBox(
                height: 36,
                width: 36,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  data.headline,
                  maxLines: 1,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: data.accent,
                    height: 1.05,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, size: 18, color: data.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact prediction tile for the two-column grid.
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
    final urgent = data.urgency != PredictionUrgency.normal;
    return Semantics(
      button: true,
      label: _semantics(data),
      excludeSemantics: true,
      child: AppCard(
        tier: AppCardTier.raised,
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBadge(data, size: 16),
                const Spacer(),
                if (data.aiRefined)
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: palette.accent,
                  ),
                if (urgent) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: data.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
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
                    color: data.accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              data.detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
