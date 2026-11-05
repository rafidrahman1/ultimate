import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/predictions/prediction_cards.dart';
import 'package:personal/features/dashboard/predictions/prediction_explanation.dart';
import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Predictions page body: group filter chips, a featured card, a grid of the
/// next four, and the rest as a dated list. Every prediction is shown.
class PredictionList extends StatefulWidget {
  const PredictionList({
    super.key,
    required this.cards,
    required this.busyKeys,
    required this.onOpen,
  });

  /// Cards shown in the grid after the featured one; the rest go to the list.
  static const gridCount = 4;

  final List<PredictionCardData> cards;
  final Set<String> busyKeys;
  final ValueChanged<PredictionCardData> onOpen;

  @override
  State<PredictionList> createState() => _PredictionListState();
}

IconData _groupIcon(PredictionGroup g) => switch (g) {
  PredictionGroup.money => Icons.account_balance_wallet_outlined,
  PredictionGroup.body => Icons.favorite_border_rounded,
  PredictionGroup.life => Icons.auto_awesome_outlined,
};

class _PredictionListState extends State<PredictionList> {
  PredictionGroup? _group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
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
    final hero = filtered.isEmpty ? null : filtered.first;
    final rest = filtered.skip(1).toList();
    final tiles = rest.take(PredictionList.gridCount).toList();
    final upcoming = rest.skip(PredictionList.gridCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groups.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(
                  context,
                  label: 'All',
                  icon: null,
                  selected: group == null,
                  onTap: () => setState(() => _group = null),
                ),
                for (final g in groups)
                  _chip(
                    context,
                    label: g.label,
                    icon: _groupIcon(g),
                    selected: group == g,
                    onTap: () => setState(() => _group = g),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        if (hero != null)
          PredictionHero(
            data: hero,
            busy: widget.busyKeys.contains(hero.key),
            onTap: () => widget.onOpen(hero),
          ),
        for (var i = 0; i < tiles.length; i += 2) ...[
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tile(tiles[i])),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: i + 1 < tiles.length
                      ? _tile(tiles[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('YOUR UPCOMING PREDICTIONS', style: context.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < upcoming.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: palette.border),
                  _UpcomingRow(
                    data: upcoming[i],
                    busy: widget.busyKeys.contains(upcoming[i].key),
                    onTap: () => widget.onOpen(upcoming[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Nothing in this group yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
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

  Widget _chip(
    BuildContext context, {
    required String label,
    required IconData? icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final palette = context.palette;
    final color = selected ? palette.statusGood : palette.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? palette.statusGood.withValues(alpha: AppOpacity.medium)
                  : palette.card,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: selected
                    ? palette.statusGood.withValues(alpha: 0.5)
                    : palette.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? palette.textPrimary : color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _semantics(PredictionCardData d) =>
    '${d.label}: ${d.headline}. ${d.detail}'
    '${d.confidence == null ? '' : '. ${d.confidence!.label} confidence'}'
    '${d.aiRefined ? '. Refined with AI' : ''}';

/// Icon in a soft accent-tinted rounded square.
class _IconBadge extends StatelessWidget {
  const _IconBadge(this.data, {this.size = 18});

  final PredictionCardData data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.5),
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

/// The lead prediction: tinted card with the figure big, a confidence pill
/// and the boxed "Why this estimate?".
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IconBadge(data, size: 22),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          data.label.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.sectionLabel,
                        ),
                      ),
                      if (data.confidence != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: PredictionConfidencePill(
                            confidence: data.confidence!,
                          ),
                        ),
                      ] else
                        _StatusPill(data),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
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
                  Text(
                    data.detail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Row(
                      children: [
                        if (data.date != null)
                          Expanded(
                            child: Text(
                              DateFormat('EEE, MMM d').format(data.date!),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: palette.textMuted,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        Text(
                          'Details',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: data.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: data.accent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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

/// A compact prediction card for the two-column grid.
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconBadge(data, size: 18),
                const Spacer(),
                if (data.confidence != null)
                  Flexible(
                    child: PredictionConfidencePill(
                      confidence: data.confidence!,
                      compact: true,
                    ),
                  )
                else
                  _StatusPill(data),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
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
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              data.detail,
              maxLines: 3,
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

/// One row of the upcoming list: icon, title and detail, date or headline.
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({
    required this.data,
    required this.onTap,
    required this.busy,
  });

  final PredictionCardData data;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final trailing = data.date != null
        ? DateFormat('MMM d, y').format(data.date!)
        : data.headline;
    return Semantics(
      button: true,
      label: _semantics(data),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              _IconBadge(data, size: 18),
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
                      data.detail,
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
                Flexible(
                  child: Text(
                    trailing,
                    maxLines: 2,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              Icon(Icons.chevron_right_rounded, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
