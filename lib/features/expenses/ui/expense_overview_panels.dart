part of 'expenses_screen.dart';

/// Daily columns with an average line, switchable to a running total.
class SpendingByDay extends StatefulWidget {
  const SpendingByDay({
    super.key,
    required this.days,
    required this.average,
    required this.money,
    required this.moneyExact,
  });

  final List<DayBarDatum> days;
  final double? average;
  final NumberFormat money;
  final NumberFormat moneyExact;

  @override
  State<SpendingByDay> createState() => SpendingByDayState();
}

class SpendingByDayState extends State<SpendingByDay> {
  bool _cumulative = false;

  List<DayBarDatum> get _data {
    if (!_cumulative) return widget.days;
    var running = 0.0;
    return [
      for (final d in widget.days) DayBarDatum(d.date, running += d.value),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppSemanticColors.expenses(context);
    final palette = context.palette;
    Widget toggle(String label, bool on) => Semantics(
      button: true,
      selected: _cumulative == on,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: () => setState(() => _cumulative = on),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _cumulative == on
                ? accent.withValues(alpha: 0.28)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: _cumulative == on ? FontWeight.w700 : FontWeight.w500,
              color: _cumulative == on
                  ? palette.textPrimary
                  : palette.textSecondary,
            ),
          ),
        ),
      ),
    );

    return CategoryPanel(
      title: 'Spending by day',
      trailing: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.cardElevated,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    toggle('Daily', false),
                    toggle('Cumulative', true),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DayBars(
            key: ValueKey(_cumulative),
            data: _data,
            color: accent,
            target: _cumulative ? null : widget.average,
            targetLabel: widget.average == null
                ? null
                : 'Avg ${widget.money.format(widget.average)}',
            format: widget.moneyExact.format,
            emptyLabel: 'No spending recorded this month',
          ),
        ],
      ),
    );
  }
}

/// Ranked categories: icon, name, bar, amount and share of the total.
class CategoryRanking extends StatelessWidget {
  const CategoryRanking({
    super.key,
    required this.items,
    required this.total,
    required this.money,
    required this.limit,
    this.onSeeAll,
  });

  final List<({String label, double value})> items;
  final double total;
  final NumberFormat money;
  final int limit;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.expenses(context);
    final shown = items.take(limit).toList();
    final maxValue = shown.isEmpty ? 1.0 : shown.first.value;

    return CategoryPanel(
      title: 'Spending by category',
      trailing: money.format(total),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Semantics(
                label:
                    '${item.label}, ${money.format(item.value)}, '
                    '${total > 0 ? (item.value / total * 100).round() : 0} percent',
                excludeSemantics: true,
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: AppOpacity.medium),
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      child: SizedBox.square(
                        dimension: 40,
                        child: Icon(
                          _categoryIcon(item.label),
                          size: 20,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    money.format(item.value),
                                    maxLines: 1,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 40),
                                child: Text(
                                  total > 0
                                      ? '${(item.value / total * 100).round()}%'
                                      : '',
                                  maxLines: 1,
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: palette.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            child: LinearProgressIndicator(
                              value: maxValue > 0
                                  ? (item.value / maxValue).clamp(0.0, 1.0)
                                  : 0,
                              minHeight: 6,
                              color: accent,
                              backgroundColor: palette.border,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (onSeeAll != null && items.length > limit)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onSeeAll,
                child: Text('See all ${items.length}'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Verdict on the projected month against the budget, from the same
/// projection the insights use.
class BudgetOutlookCard extends StatelessWidget {
  const BudgetOutlookCard({
    super.key,
    required this.projected,
    required this.budget,
    required this.money,
  });

  final double projected;
  final double budget;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final over = projected > budget;
    final color = over ? palette.warning : palette.statusGood;
    final diff = (budget - projected).abs();
    final pct = (projected / budget * 100).round();

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.track_changes_rounded, size: 18, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'BUDGET OUTLOOK',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.sectionLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          over ? 'Likely over' : 'On track',
          style: context.statDisplay.copyWith(
            fontSize: 26,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Projected spend: ${money.format(projected)} ($pct% of budget)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textSecondary,
          ),
        ),
      ],
    );

    final chip = DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.medium),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              over ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              '≈${money.format(diff)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              over ? 'over budget' : 'under budget',
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Side by side only when there is room for both.
          final roomy =
              constraints.maxWidth >= 340 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.3;
          return roomy
              ? Row(
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: AppSpacing.md),
                    chip,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    summary,
                    const SizedBox(height: AppSpacing.md),
                    Align(alignment: Alignment.centerLeft, child: chip),
                  ],
                );
        },
      ),
    );
  }
}
