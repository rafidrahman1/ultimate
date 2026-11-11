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
  if (has(['coffee', 'cafe', 'tea'])) return Icons.local_cafe_outlined;
  if (has(['educat', 'school', 'course', 'book', 'tuition'])) {
    return Icons.school_outlined;
  }
  if (has(['gym', 'fitness', 'sport'])) return Icons.fitness_center_outlined;
  if (has(['gift', 'donat', 'charity', 'zakat'])) {
    return Icons.card_giftcard_outlined;
  }
  if (has(['phone', 'mobile', 'recharge', 'data'])) {
    return Icons.smartphone_outlined;
  }
  if (has(['insur'])) return Icons.shield_outlined;
  if (has(['salon', 'beauty', 'personal care', 'barber'])) {
    return Icons.content_cut_outlined;
  }
  if (has(['home', 'house', 'furnit', 'repair', 'maintenance'])) {
    return Icons.home_repair_service_outlined;
  }
  if (has(['saving', 'invest'])) return Icons.savings_outlined;
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
                  fontWeight: FontWeight.w700,
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
