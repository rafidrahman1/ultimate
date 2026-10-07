import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/prediction_cards.dart';
import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Predictions as one compact list: filter chips by group, most urgent first,
/// and the "All" view collapsed to the first few so the dashboard stays short.
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
    final palette = context.palette;
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
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md,
                    color: palette.border,
                  ),
                PredictionRow(
                  data: shown[i],
                  busy: widget.busyKeys.contains(shown[i].key),
                  onTap: () => widget.onOpen(shown[i]),
                ),
              ],
            ],
          ),
        ),
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

/// One prediction as a row: what it is and a line of detail on the left, the
/// headline figure on the right.
class PredictionRow extends StatelessWidget {
  const PredictionRow({
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
      label:
          '${data.label}: ${data.headline}. ${data.detail}'
          '${data.aiRefined ? '. Refined with AI' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: data.accent.withValues(alpha: AppOpacity.medium),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
                child: Icon(data.icon, size: 18, color: data.accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            data.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                        if (data.aiRefined) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 12,
                            color: palette.accent,
                          ),
                        ],
                      ],
                    ),
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
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 128),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          data.headline,
                          maxLines: 1,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: data.accent,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: urgent ? data.accent : palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
