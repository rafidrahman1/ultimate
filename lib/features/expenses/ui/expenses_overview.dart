part of 'expenses_screen.dart';

enum ExpensesTab {
  overview('Overview'),
  transactions('Transactions'),
  categories('Categories'),
  insights('Insights');

  const ExpensesTab(this.label);
  final String label;
}

/// Pill-style tab row; the selected tab is tinted with the expenses accent.
class ExpensesTabs extends StatelessWidget {
  const ExpensesTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ExpensesTab selected;
  final ValueChanged<ExpensesTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = AppSemanticColors.expenses(context);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final tab in ExpensesTab.values)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: tab == selected,
                  label: tab.label,
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    onTap: () => onSelected(tab),
                    child: AnimatedContainer(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tab == selected
                            ? accent.withValues(alpha: 0.28)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          tab.label,
                          maxLines: 1,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: tab == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: tab == selected
                                ? palette.textPrimary
                                : palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Icon for a spending category, matched by keyword; falls back to a tag.
IconData _categoryIcon(String name) {
  final n = name.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  if (has(['food', 'dining', 'restaurant', 'grocer', 'meal', 'snack'])) {
    return Icons.restaurant_rounded;
  }
  if (has(['fuel', 'petrol', 'gas', 'octane'])) {
    return Icons.local_gas_station_rounded;
  }
  if (has(['shop', 'misc', 'cloth', 'store'])) {
    return Icons.shopping_cart_outlined;
  }
  if (has(['transport', 'ride', 'bus', 'taxi', 'uber', 'travel'])) {
    return Icons.directions_car_filled_outlined;
  }
  if (has(['bill', 'util', 'rent', 'internet', 'electric'])) {
    return Icons.receipt_long_outlined;
  }
  if (has(['health', 'medic', 'pharma'])) {
    return Icons.medical_services_outlined;
  }
  if (has(['game', 'entertain', 'movie', 'subscript'])) {
    return Icons.sports_esports_outlined;
  }
  return Icons.sell_outlined;
}

/// Total spent, budget ring, and the three numbers that matter most.
class SpendingHero extends StatelessWidget {
  const SpendingHero({
    super.key,
    required this.spent,
    required this.budget,
    required this.projected,
    required this.daysElapsed,
    required this.periodLabel,
    required this.money,
    required this.footnoteStats,
    required this.caption,
  });

  final double spent;
  final double? budget;
  final double? projected;
  final int daysElapsed;
  final String periodLabel;
  final NumberFormat money;
  final List<({String label, String value})> footnoteStats;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.expenses(context);
    final hasBudget = budget != null && budget! > 0;
    final percent = hasBudget ? spent / budget! * 100 : null;
    final remaining = hasBudget ? budget! - spent : null;
    final avg = daysElapsed > 0 ? spent / daysElapsed : null;
    final projectedColor = projected == null
        ? palette.textPrimary
        : hasBudget && projected! > budget!
        ? palette.warning
        : palette.statusGood;

    Widget stat(String label, String value, {Color? color}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return AppCard(
      tier: AppCardTier.hero,
      accent: accent,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: AppOpacity.strong),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: accent,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SPENDING', style: context.sectionLabel),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money.format(spent),
                        maxLines: 1,
                        style: context.statDisplay.copyWith(
                          fontSize: 34,
                          color: accent,
                        ),
                      ),
                    ),
                    Text(
                      daysElapsed > 0
                          ? '$periodLabel · $daysElapsed '
                                '${daysElapsed == 1 ? 'day' : 'days'}'
                          : periodLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (percent != null) ...[
                const SizedBox(width: AppSpacing.sm),
                RingGauge(
                  percent: percent,
                  color: accent,
                  label: 'used',
                  size: 84,
                ),
              ],
            ],
          ),
          if (hasBudget)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'of ${money.format(budget)} monthly budget',
                textAlign: TextAlign.end,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: palette.border),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (avg != null) stat('Avg per day', money.format(avg)),
              if (remaining != null)
                stat(
                  remaining < 0 ? 'Over by' : 'Remaining',
                  money.format(remaining.abs()),
                  color: remaining < 0 ? palette.warning : null,
                ),
              if (projected != null)
                stat(
                  'Projected',
                  money.format(projected),
                  color: projectedColor,
                ),
            ],
          ),
          if (footnoteStats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: 2,
              children: [
                for (final s in footnoteStats)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${s.label} ',
                          style: TextStyle(color: palette.textMuted),
                        ),
                        TextSpan(
                          text: s.value,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    style: theme.textTheme.labelSmall,
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

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
