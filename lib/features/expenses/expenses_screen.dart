import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/status_message.dart';
import 'cashew_transaction.dart';
import 'expenses_service.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(expensesSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          if (summary.transactions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear',
              onPressed: () => ref.read(expensesSummaryProvider.notifier).clear(),
            ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Cashew CSV',
            onPressed: () => _importCsv(context, ref),
          ),
        ],
      ),
      body: summary.transactions.isEmpty
          ? const StatusMessage(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No expenses loaded',
              subtitle:
                  'Tap the upload icon to import a Cashew CSV export from Downloads.',
            )
          : _ExpensesBody(summary: summary),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _importCsv(context, ref),
        icon: const Icon(Icons.upload_file),
        label: const Text('Import CSV'),
      ),
    );
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(expensesSummaryProvider.notifier).importFromPicker();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

class _ExpensesBody extends StatelessWidget {
  const _ExpensesBody({required this.summary});

  final ExpensesSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = summary.currency;
    final amountFormat = NumberFormat.currency(
      symbol: currency == 'BDT' ? '৳' : '$currency ',
      decimalDigits: 2,
    );
    final percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 2);
    final dateFormat = DateFormat('d MMM yyyy');
    final transactions = summary.sortedByDate;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (summary.fileName != null)
                  Text(
                    summary.fileName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (summary.fileName != null) const SizedBox(height: 12),
                MetricCard(
                  title: 'Real expenses',
                  value: amountFormat.format(summary.totalRealExpenses),
                  icon: Icons.arrow_downward,
                  color: AppColors.expenses,
                  subtitle:
                      '${summary.realExpenseCount} transactions · excludes transfers',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  title: 'Income received',
                  value: amountFormat.format(summary.totalIncome),
                  icon: Icons.arrow_upward,
                  color: AppColors.chat,
                  subtitle: 'Salary & cash in only',
                ),
                const SizedBox(height: 12),
                MetricCard(
                  title: 'Net surplus',
                  value: amountFormat.format(summary.netSurplus),
                  icon: Icons.savings_outlined,
                  color: AppColors.result,
                  subtitle: summary.burnRate != null
                      ? 'Burn rate ${percentFormat.format(summary.burnRate)}'
                      : null,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
          sliver: SliverList.separated(
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return _TransactionTile(
                transaction: tx,
                amountFormat: amountFormat,
                dateFormat: dateFormat,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.amountFormat,
    required this.dateFormat,
  });

  final CashewTransaction transaction;
  final NumberFormat amountFormat;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTransfer = transaction.isBalanceCorrection;
    final isIncome = transaction.isRealIncome;
    final amountColor = isTransfer
        ? theme.colorScheme.onSurfaceVariant
        : isIncome
            ? AppColors.chat
            : theme.colorScheme.onSurface;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.displayTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.account} · ${dateFormat.format(transaction.date)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (transaction.note != null && transaction.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        transaction.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isTransfer
                  ? '—'
                  : '${isIncome ? '+' : ''}${amountFormat.format(transaction.amount.abs())}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
