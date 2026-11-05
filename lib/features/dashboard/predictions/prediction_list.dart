import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/predictions/prediction_cards.dart';
import 'package:personal/features/dashboard/predictions/prediction_explanation.dart';
import 'package:personal/features/dashboard/predictions/prediction_visuals.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/sparkline.dart';

/// Predictions page body: filter chips, a featured card, a grid of the next
/// four, and the rest as a dated list. Every prediction is shown.
class PredictionList extends StatefulWidget {
  const PredictionList({
    super.key,
    required this.cards,
    required this.busyKeys,
    required this.onOpen,
    this.onManage,
    this.onHide,
    this.onRefineAll,
    this.refiningAll = false,
    this.onSetupAi,
  });

  /// Cards shown in the grid after the featured one; the rest go to the list.
  static const gridCount = 4;

  final List<PredictionCardData> cards;
  final Set<String> busyKeys;
  final ValueChanged<PredictionCardData> onOpen;

  /// Opens the chooser for which predictions to show.
  final VoidCallback? onManage;

  /// Switches one prediction off (from a row's menu).
  final ValueChanged<String>? onHide;

  /// Refines every prediction with the AI provider; null when none is set up.
  final VoidCallback? onRefineAll;
  final bool refiningAll;

  /// Opens the AI provider settings; shown instead of the refine button when
  /// [onRefineAll] is null.
  final VoidCallback? onSetupAi;

  @override
  State<PredictionList> createState() => _PredictionListState();
}

Color _groupColor(BuildContext context, PredictionUiGroup g) => switch (g) {
  PredictionUiGroup.finance => context.palette.accent,
  PredictionUiGroup.mobility => AppSemanticColors.location(context),
  PredictionUiGroup.routine => AppSemanticColors.calendar(context),
  PredictionUiGroup.life => context.palette.accent,
};

class _PredictionListState extends State<PredictionList> {
  PredictionUiGroup? _group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final groups = [
      for (final g in PredictionUiGroup.values)
        if (widget.cards.any((c) => c.uiGroup == g)) g,
    ];
    // A filter whose cards vanished falls back to "All".
    final group = groups.contains(_group) ? _group : null;
    final filtered = [
      for (final c in widget.cards)
        if (group == null || c.uiGroup == group) c,
    ];
    final hero = filtered.isEmpty ? null : filtered.first;
    // The cards with illustrations lead the grid; the rest keep their order.
    const preferred = ['fuel', 'commute', 'bills', 'bestDay'];
    final others = filtered.skip(1).toList();
    final rest = [
      for (final key in preferred) ...others.where((c) => c.key == key),
      ...others.where((c) => !preferred.contains(c.key)),
    ];
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
                  iconColor: palette.textPrimary,
                  selected: group == null,
                  onTap: () => setState(() => _group = null),
                ),
                for (final g in groups)
                  _chip(
                    context,
                    label: g.label,
                    icon: g.icon,
                    iconColor: _groupColor(context, g),
                    selected: group == g,
                    onTap: () => setState(() => _group = g),
                  ),
              ],
            ),
          ),
        if (widget.cards.isNotEmpty &&
            (widget.onRefineAll != null ||
                widget.refiningAll ||
                widget.onSetupAi != null)) ...[
          const SizedBox(height: AppSpacing.md),
          _RefineBar(
            onRefine: widget.onRefineAll,
            refining: widget.refiningAll,
            onSetup: widget.onSetupAi,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (hero != null)
          PredictionHero(
            data: hero,
            busy: widget.busyKeys.contains(hero.key),
            onTap: () => widget.onOpen(hero),
          ),
        for (final tile in tiles) ...[
          const SizedBox(height: AppSpacing.md),
          _tile(tile),
        ],
        if (upcoming.isNotEmpty || widget.onManage != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('YOUR UPCOMING PREDICTIONS', style: context.sectionLabel),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.onManage != null)
                    TextButton.icon(
                      onPressed: widget.onManage,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Manage'),
                    ),
                ],
              ),
            ],
          ),
        ],
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
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
                    onHide: widget.onHide == null
                        ? null
                        : () => widget.onHide!(upcoming[i].key),
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
    required Color iconColor,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final palette = context.palette;
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? palette.statusGood.withValues(alpha: 0.22)
                  : palette.card,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: selected
                    ? palette.statusGood.withValues(alpha: 0.7)
                    : palette.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: palette.textPrimary,
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

/// Always-visible entry point for AI refinement: a refine button when a
/// provider is ready, otherwise a shortcut to set one up.
class _RefineBar extends StatelessWidget {
  const _RefineBar({this.onRefine, this.refining = false, this.onSetup});

  final VoidCallback? onRefine;
  final bool refining;
  final VoidCallback? onSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final ready = onRefine != null || refining;
    final title = refining
        ? 'Refining with AI…'
        : ready
        ? 'Refine with AI'
        : 'AI refinement is off';
    final subtitle = ready
        ? 'Sharpen dates and amounts using your AI provider'
        : 'Add an API key to refine predictions with AI';
    final button = refining
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : FilledButton.tonal(
            onPressed: ready ? onRefine : onSetup,
            child: Text(ready ? 'Refine all' : 'Set up'),
          );

    return Semantics(
      container: true,
      label: '$title. $subtitle',
      child: AppCard(
        tier: AppCardTier.flat,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Builder(
          builder: (context) {
            final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
            final info = Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: AppOpacity.strong),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: palette.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  info,
                  const SizedBox(height: AppSpacing.sm),
                  Align(alignment: Alignment.centerRight, child: button),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: AppSpacing.sm),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}

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
