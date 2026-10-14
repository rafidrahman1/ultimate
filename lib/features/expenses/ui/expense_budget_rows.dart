part of 'expenses_screen.dart';

class _ExpenseBucketStat {
  const _ExpenseBucketStat({
    required this.name,
    required this.amount,
    required this.count,
  });

  final String name;
  final double amount;
  final int count;
}

/// Spend against the monthly budget; turns to the warning colour once over.
class _BudgetBar extends StatelessWidget {
  const _BudgetBar({
    required this.spent,
    required this.budget,
    required this.money,
  });

  final double spent;
  final double budget;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final ratio = spent / budget;
    final over = ratio > 1;
    final color = over
        ? palette.warning
        : ratio > 0.85
        ? palette.warning.withValues(alpha: 0.85)
        : AppSemanticColors.expenses(context);
    final left = budget - spent;

    return Semantics(
      label:
          '${(ratio * 100).round()} percent of the ${money.format(budget)} budget used',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: palette.border,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${(ratio * 100).round()}% of ${money.format(budget)} budget',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                over
                    ? '${money.format(-left)} over'
                    : '${money.format(left)} left',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: over ? palette.warning : palette.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.money,
    this.excluded = false,
  });

  final CashewTransaction transaction;
  final NumberFormat money;
  final bool excluded;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isTransfer = transaction.isBalanceCorrection;
    final isSavings = transaction.isSavingsTransfer;
    final isLoan = transaction.isLoanMovement;
    final isIncome = transaction.isRealIncome;
    final accent = AppSemanticColors.expenses(context);
    final income = AppSemanticColors.accent(context);
    final amount = money.format(transaction.amount.abs());

    return CategoryRow(
      icon: isTransfer
          ? Icons.swap_horiz_rounded
          : isSavings
          ? Icons.savings_outlined
          : isLoan
          ? Icons.handshake_outlined
          : isIncome
          ? Icons.south_west_rounded
          : Icons.north_east_rounded,
      accent: isIncome || isSavings ? income : accent,
      muted: isTransfer || isSavings || isLoan || excluded,
      title: transaction.displayTitle,
      subtitle: excluded
          ? '${transaction.account} · Excluded'
          : transaction.account,
      detail: transaction.note,
      trailing: isTransfer
          ? '—'
          : isSavings
          ? (transaction.withdrawnAmount > 0
                ? 'from savings $amount'
                : 'saved $amount')
          : isLoan
          ? 'loan $amount'
          : '${isIncome ? '+' : '-'}$amount',
      trailingColor: isIncome
          ? income
          : excluded
          ? palette.textMuted
          : palette.textPrimary,
    );
  }
}
