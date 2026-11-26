import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/predictions/prediction_cards.dart';
import 'package:personal/features/dashboard/predictions/prediction_explanation.dart';
import 'package:personal/shared/widgets/sparkline.dart';

/// Predictions page body, built for scanning: a one-line toolbar (filters,
/// AI refine, manage), a count summary, then every prediction as a compact
/// card in a dense grid, grouped by area when no filter is set.
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

  final List<PredictionCardData> cards;
  final Set<String> busyKeys;
  final ValueChanged<PredictionCardData> onOpen;

  /// Opens the chooser for which predictions to show.
  final VoidCallback? onManage;

  /// Switches one prediction off (from a card's long-press menu).
  final ValueChanged<String>? onHide;

  /// Refines every prediction with the AI provider; null when none is set up.
  final VoidCallback? onRefineAll;
  final bool refiningAll;

  /// Opens the AI provider settings; used instead of refining when
  /// [onRefineAll] is null.
  final VoidCallback? onSetupAi;

  @override
  State<PredictionList> createState() => _PredictionListState();
}

Color _groupColor(BuildContext context, PredictionUiGroup g) => switch (g) {
  PredictionUiGroup.finance => AppSemanticColors.expenses(context),
  PredictionUiGroup.mobility => AppSemanticColors.location(context),
  PredictionUiGroup.routine => AppSemanticColors.calendar(context),
  PredictionUiGroup.life => AppSemanticColors.health(context),
};

String _semantics(PredictionCardData d) =>
    '${d.label}: ${d.figure ?? d.headline}. ${d.shortDetail ?? d.detail}'
    '${d.confidence == null ? '' : '. ${d.confidence!.label} confidence'}'
    '${d.aiRefined ? '. Refined with AI' : ''}';

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

    final sections = <Widget>[];
    if (group == null && groups.length > 1) {
      for (final g in groups) {
        final cards = [
          for (final c in filtered)
            if (c.uiGroup == g) c,
        ];
        sections
          ..add(const SizedBox(height: AppSpacing.lg))
          ..add(_GroupHeader(group: g, count: cards.length))
          ..add(const SizedBox(height: AppSpacing.sm))
          ..add(_grid(cards));
      }
    } else if (filtered.isNotEmpty) {
      sections
        ..add(const SizedBox(height: AppSpacing.md))
        ..add(_grid(filtered));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (groups.length > 1) ...[
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
                  ],
                ),
              ),
            ),
            _RefineButton(
              onRefine: widget.onRefineAll,
              refining: widget.refiningAll,
              onSetup: widget.onSetupAi,
            ),
            if (widget.onManage != null)
              IconButton(
                tooltip: 'Choose predictions',
                onPressed: widget.onManage,
                icon: const Icon(Icons.tune_rounded),
              ),
          ],
        ),
        if (widget.cards.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _Summary(cards: filtered),
        ],
        ...sections,
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

  Widget _grid(List<PredictionCardData> cards) => _PredictionGrid(
    cards: cards,
    busyKeys: widget.busyKeys,
    onOpen: widget.onOpen,
    onHide: widget.onHide,
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
      padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? palette.textPrimary.withValues(alpha: AppOpacity.medium)
                  : palette.card,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: selected ? palette.textSecondary : palette.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

/// "12 predictions · 2 urgent · 3 soon · 4 refined with AI".
class _Summary extends StatelessWidget {
  const _Summary({required this.cards});

  final List<PredictionCardData> cards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    int count(PredictionUrgency u) => cards.where((c) => c.urgency == u).length;
    final urgent = count(PredictionUrgency.critical);
    final soon = count(PredictionUrgency.soon);
    final refined = cards.where((c) => c.aiRefined).length;
    final base = theme.textTheme.bodySmall?.copyWith(color: palette.textMuted);
    final strong = base?.copyWith(fontWeight: FontWeight.w700);
    const dot = TextSpan(text: '  ·  ');
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(
            text: '${cards.length} ',
            style: strong?.copyWith(color: palette.textPrimary),
          ),
          TextSpan(text: cards.length == 1 ? 'prediction' : 'predictions'),
          if (urgent > 0) ...[
            dot,
            TextSpan(
              text: '$urgent urgent',
              style: strong?.copyWith(color: palette.statusCritical),
            ),
          ],
          if (soon > 0) ...[
            dot,
            TextSpan(
              text: '$soon soon',
              style: strong?.copyWith(color: palette.warning),
            ),
          ],
          if (refined > 0) ...[dot, TextSpan(text: '$refined refined by AI')],
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.count});

  final PredictionUiGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(group.icon, size: 14, color: _groupColor(context, group)),
          const SizedBox(width: 6),
          Text(group.label.toUpperCase(), style: context.sectionLabel),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: context.sectionLabel.copyWith(color: palette.textMuted),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Divider(height: 1, color: palette.border)),
        ],
      ),
    );
  }
}

/// Cards in equal-height rows: two columns on phones, three when wide, one
/// at very large text sizes.
class _PredictionGrid extends StatelessWidget {
  const _PredictionGrid({
    required this.cards,
    required this.busyKeys,
    required this.onOpen,
    this.onHide,
  });

  final List<PredictionCardData> cards;
  final Set<String> busyKeys;
  final ValueChanged<PredictionCardData> onOpen;
  final ValueChanged<String>? onHide;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = scale > 1.6
            ? 1
            : constraints.maxWidth >= 540
            ? 3
            : 2;
        const gap = AppSpacing.sm;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var start = 0; start < cards.length; start += columns) ...[
              if (start > 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < columns; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      Expanded(
                        child: start + i < cards.length
                            ? _card(cards[start + i])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _card(PredictionCardData d) => PredictionCompactCard(
    data: d,
    busy: busyKeys.contains(d.key),
    onTap: () => onOpen(d),
    onHide: onHide == null ? null : () => onHide!(d.key),
  );
}

/// One prediction in a small footprint: label, headline figure, short
/// detail, then whichever of progress / trend / date it has, plus
/// confidence. Long-press offers to hide it.
class PredictionCompactCard extends StatelessWidget {
  const PredictionCompactCard({
    super.key,
    required this.data,
    required this.onTap,
    this.onHide,
    this.busy = false,
  });

  final PredictionCardData data;
  final VoidCallback onTap;
  final VoidCallback? onHide;
  final bool busy;

  String? get _when {
    final date = data.date;
    if (date == null) return null;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(today).inDays;
    final day = DateFormat(
      date.year == now.year ? 'EEE, MMM d' : 'MMM d, y',
    ).format(date);
    if (days < 0) return '$day · ${-days} d ago';
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days <= 14) return '$day · ${days}d';
    return day;
  }

  Future<void> _menu(BuildContext context) async {
    final hide = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(data.icon, color: data.accent),
              title: Text(data.label),
              subtitle: Text(data.headline),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.open_in_full_rounded),
              title: const Text('Open details'),
              onTap: () => Navigator.pop(sheet, false),
            ),
            if (onHide != null)
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Hide this prediction'),
                onTap: () => Navigator.pop(sheet, true),
              ),
          ],
        ),
      ),
    );
    if (hide == true) {
      onHide?.call();
    } else if (hide == false) {
      onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final urgent = data.urgency != PredictionUrgency.normal;
    final statusColor = switch (data.urgency) {
      PredictionUrgency.critical => palette.statusCritical,
      PredictionUrgency.soon => palette.warning,
      PredictionUrgency.normal => null,
    };
    final when = _when;
    final hasProgress = data.progress != null;
    final hasSeries = data.series.length >= 2;
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: palette.textMuted,
    );

    return Semantics(
      button: true,
      label: _semantics(data),
      onLongPressHint: onHide == null ? null : 'More options',
      excludeSemantics: true,
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(
            color: statusColor?.withValues(alpha: 0.55) ?? palette.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _menu(context),
          child: Stack(
            children: [
              // Accent spine down the left edge.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: ColoredBox(
                  color: statusColor ?? data.accent.withValues(alpha: 0.6),
                  child: const SizedBox(width: 3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm + 2,
                  AppSpacing.sm + 2,
                  AppSpacing.sm + 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(data.icon, size: 15, color: data.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            data.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (data.aiRefined)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: 12,
                              color: palette.accent,
                            ),
                          ),
                        if (urgent)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: statusColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (busy)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          data.headline,
                          maxLines: 1,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: statusColor ?? palette.textPrimary,
                            height: 1.15,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      data.shortDetail ?? data.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        height: 1.25,
                      ),
                    ),
                    const Spacer(),
                    if (hasProgress) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        child: LinearProgressIndicator(
                          value: data.progress!.clamp(0.0, 1.0),
                          minHeight: 4,
                          color: statusColor ?? data.accent,
                          backgroundColor: palette.border,
                        ),
                      ),
                      if (data.progressRight != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          data.progressRight!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                      ],
                    ] else if (hasSeries) ...[
                      const SizedBox(height: AppSpacing.sm),
                      // Infinite width: the painter fills the card's width.
                      // (No LayoutBuilder: the grid rows use IntrinsicHeight.)
                      Sparkline(
                        values: data.series,
                        color: data.accent,
                        width: double.infinity,
                        height: 20,
                      ),
                    ],
                    if (when != null || data.confidence != null) ...[
                      const SizedBox(height: AppSpacing.xs + 2),
                      Row(
                        children: [
                          if (when != null) ...[
                            Icon(
                              Icons.event_outlined,
                              size: 12,
                              color: palette.textMuted,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                when,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: muted,
                              ),
                            ),
                          ] else
                            const Spacer(),
                          if (data.confidence != null)
                            Tooltip(
                              message: '${data.confidence!.label} confidence',
                              child: PredictionConfidenceIndicator(
                                confidence: data.confidence!,
                                showLabel: false,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toolbar action for AI refinement: refine everything when a provider is
/// ready, otherwise a shortcut to set one up.
class _RefineButton extends StatelessWidget {
  const _RefineButton({this.onRefine, this.refining = false, this.onSetup});

  final VoidCallback? onRefine;
  final bool refining;
  final VoidCallback? onSetup;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (refining) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    final ready = onRefine != null;
    if (!ready && onSetup == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: ready
          ? 'Refine all with AI'
          : 'AI refinement is off — set up a provider',
      onPressed: ready ? onRefine : onSetup,
      icon: Icon(
        ready ? Icons.auto_awesome_rounded : Icons.auto_awesome_outlined,
        color: ready ? palette.accent : palette.textMuted,
      ),
    );
  }
}
