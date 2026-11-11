import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/predictions/prediction_cards.dart';
import 'package:personal/features/dashboard/predictions/prediction_explanation.dart';
import 'package:personal/features/dashboard/predictions/prediction_visuals.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/sparkline.dart';

part 'prediction_tiles.dart';
part 'prediction_hero.dart';

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
