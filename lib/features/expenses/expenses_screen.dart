import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../theme/app_theme.dart';
import '../../widgets/analysis_prompt_preview_card.dart';
import '../../widgets/collapsible_summary_section.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/pinned_summary_layout.dart';
import '../../widgets/pinned_summary_skeleton.dart';
import '../../widgets/status_message.dart';
import 'cashew_transaction.dart';
import 'expenses_service.dart';
import 'expenses_settings_service.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromFolder());
  }

  Future<void> _loadFromFolder() async {
    final settings = ref.read(expensesSettingsProvider).valueOrNull;
    if (settings == null || !settings.hasFolder || settings.needsReselect) {
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      await ref.read(expensesSummaryProvider.notifier).loadFromConfiguredFolder();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(expensesSummaryProvider);
    final settings = ref.watch(expensesSettingsProvider).valueOrNull;
    final hasFolder = settings?.hasFolder ?? false;
    final needsReselect = settings?.needsReselect ?? false;

    ref.listen(expensesSettingsProvider, (previous, next) {
      final prevUri = previous?.valueOrNull?.cashewFolderUri;
      final nextUri = next.valueOrNull?.cashewFolderUri;
      if (prevUri != nextUri) _loadFromFolder();
    });

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
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload from folder',
            onPressed: hasFolder && !_loading ? _loadFromFolder : null,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import Cashew CSV',
            onPressed: () => _importCsv(context),
          ),
        ],
      ),
      body: _loading
          ? const PinnedSummarySkeleton(
              metricCount: 3,
              listItemStyle: PinnedSummaryListItemStyle.detailed,
            )
          : summary.transactions.isEmpty
              ? StatusMessage(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No expenses loaded',
                  subtitle: _loadError ??
                      (needsReselect
                          ? 'Open Expenses settings and choose your Cashew folder again '
                              'so Android can read files in that folder.'
                          : hasFolder
                              ? 'No cashew-*.csv export found in your selected folder. '
                                  'Tap refresh after exporting from Cashew.'
                              : 'Choose your Cashew export folder in Expenses settings, '
                                  'or tap the upload icon to import a CSV manually.'),
                  action: _successAction(context, hasFolder || needsReselect),
                )
              : _ExpensesBody(summary: summary),
      floatingActionButton: hasFolder
          ? FloatingActionButton.extended(
              onPressed: _loading ? null : _loadFromFolder,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _importCsv(context),
              icon: const Icon(Icons.upload_file),
              label: const Text('Import CSV'),
            ),
    );
  }

  Widget? _successAction(BuildContext context, bool showSettings) {
    if (!showSettings) return null;
    return FilledButton(
      onPressed: () => Navigator.pushNamed(context, AppRoutes.expensesSettings),
      child: const Text('Open settings'),
    );
  }

  Future<void> _importCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(expensesSummaryProvider.notifier).importFromPicker();
      if (!mounted) return;
      setState(() => _loadError = null);
    } catch (e) {
      messenger.showSnackBar(
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
    final promptText = summary.toAnalysisPromptText();

    return PinnedSummaryLayout(
      header: summary.fileName == null
          ? null
          : Text(
              summary.fileName!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      summary: CollapsibleSummarySection(
        title: 'Summary',
        subtitle:
            '${amountFormat.format(summary.totalRealExpenses)} expenses · '
            '${amountFormat.format(summary.netSurplus)} net',
        icon: Icons.summarize_outlined,
        accent: AppColors.expenses,
        metrics: [
          MetricCard(
            title: 'Real expenses',
            value: amountFormat.format(summary.totalRealExpenses),
            icon: Icons.arrow_downward,
            color: AppColors.expenses,
            subtitle:
                '${summary.realExpenseCount} transactions · excludes transfers',
            compact: true,
          ),
          MetricCard(
            title: 'Income received',
            value: amountFormat.format(summary.totalIncome),
            icon: Icons.arrow_upward,
            color: AppColors.accent,
            subtitle: 'Salary & cash in only',
            compact: true,
          ),
          MetricCard(
            title: 'Net surplus',
            value: amountFormat.format(summary.netSurplus),
            icon: Icons.savings_outlined,
            color: AppColors.result,
            subtitle: summary.burnRate != null
                ? 'Burn rate ${percentFormat.format(summary.burnRate)}'
                : null,
            compact: true,
          ),
        ],
        prompt: AnalysisPromptPreviewCard(
          promptText: promptText,
          detailTitle: 'Expenses data for analysis',
          accent: AppColors.expenses,
          icon: Icons.account_balance_wallet_outlined,
          compact: true,
        ),
      ),
      bodyBuilder: (context, padding) => ListView.separated(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
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
            ? AppColors.accent
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
            const SizedBox(width: 2),
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
