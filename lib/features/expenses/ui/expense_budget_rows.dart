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
