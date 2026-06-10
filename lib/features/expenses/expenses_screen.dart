import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/app/router.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/shared/widgets/analysis_prompt_preview_card.dart';
import 'package:personal/shared/widgets/collapsible_summary_section.dart';
import 'package:personal/shared/widgets/metric_card.dart';
import 'package:personal/shared/widgets/pinned_summary_layout.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/core/data_folder_settings_service.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await ref.read(expensesSummaryProvider.notifier).restoreFromCache();
    if (!mounted) return;
    await _loadFromFolderIfNeeded();
  }

  /// Auto-load from folder only when nothing is cached yet.
  Future<void> _loadFromFolderIfNeeded() async {
    if (ref.read(expensesSummaryProvider).transactions.isNotEmpty) return;
    await _loadFromFolder();
  }

  Future<void> _loadFromFolder() async {
    final settings = ref.read(dataFolderSettingsProvider).valueOrNull;
    if (settings == null || !settings.hasFolder || settings.needsReselect) {
      return;
    }

    final hasData = ref.read(expensesSummaryProvider).transactions.isNotEmpty;
    setState(() {
      if (!hasData) _loading = true;
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
    final period = ref.watch(analysisPeriodProvider);
    final summary = ref.watch(expensesForAnalysisProvider);
    final rawSummary = ref.watch(expensesSummaryProvider);
    final settings = ref.watch(dataFolderSettingsProvider).valueOrNull;
    final hasFolder = settings?.hasFolder ?? false;
    final needsReselect = settings?.needsReselect ?? false;

    ref.listen(dataFolderSettingsProvider, (previous, next) {
      final prevUri = previous?.valueOrNull?.folderUri;
      final nextUri = next.valueOrNull?.folderUri;
      if (prevUri != nextUri) _loadFromFolder();
    });

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Expenses',
        extraActions: [
          if (rawSummary.transactions.isNotEmpty)
            AppBarCircularAction(
              icon: Icons.close,
              onPressed: () => ref.read(expensesSummaryProvider.notifier).clear(),
            ),
          AppBarCircularAction(
            icon: Icons.refresh,
            onPressed: hasFolder && !_loading ? _loadFromFolder : null,
          ),
        ],
      ),
      body: _loading
          ? const PinnedSummarySkeleton(metricCount: 3, listItemStyle: PinnedSummaryListItemStyle.detailed)
          : summary.transactions.isEmpty
          ? StatusMessage(
              icon: Icons.account_balance_wallet_outlined,
              title: rawSummary.transactions.isEmpty ? 'No expenses loaded' : 'No expenses in ${period.dataRangeLabel}',
              subtitle:
                  _loadError ??
                  (needsReselect
                      ? 'Open General settings and choose your data folder again '
                            'so Android can read files in that folder.'
                      : hasFolder
                      ? 'No cashew-*.csv export found in your selected folder. '
                            'Tap refresh after exporting from Cashew.'
                      : 'Choose your data folder in General settings, '
                            'or tap the upload icon to import a CSV manually.'),
              action: _successAction(context, hasFolder || needsReselect),
            )
          : _ExpensesBody(summary: summary, periodLabel: period.dataRangeLabel),
      floatingActionButton: hasFolder
          ? FloatingActionButton.extended(onPressed: _loading ? null : _loadFromFolder, icon: const Icon(Icons.refresh), label: const Text('Reload'))
          : FloatingActionButton.extended(onPressed: () => _importCsv(context), icon: const Icon(Icons.upload_file), label: const Text('Import CSV')),
    );
  }

  Widget? _successAction(BuildContext context, bool showSettings) {
    if (!showSettings) return null;
    return FilledButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.generalSettings), child: const Text('Open settings'));
  }

  Future<void> _importCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(expensesSummaryProvider.notifier).importFromPicker();
      if (!mounted) return;
      setState(() => _loadError = null);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _ExpensesBody extends StatefulWidget {
  const _ExpensesBody({required this.summary, required this.periodLabel});

  final ExpensesSummary summary;
  final String periodLabel;

  @override
  State<_ExpensesBody> createState() => _ExpensesBodyState();
}

class _ExpensesBodyState extends State<_ExpensesBody> {
  static const String _netSurplusOption = '__net_surplus__';
  String _selectedSummaryOption = _netSurplusOption;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final periodLabel = widget.periodLabel;
    final theme = Theme.of(context);
    final currency = summary.currency;
    final amountFormat = NumberFormat.currency(symbol: currency == 'BDT' ? '৳' : '$currency ', decimalDigits: 2);
    final percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 2);
    final dateFormat = DateFormat('d MMM yyyy');
    final transactions = summary.sortedByDate;
    final promptText = summary.toAnalysisPromptText();
    final subcategoryStats = _realExpensesBySubcategory(summary.transactions);

    final selectedCategory = _selectedSummaryOption == _netSurplusOption
        ? null
        : subcategoryStats.where((stat) => stat.name == _selectedSummaryOption).cast<_ExpenseBucketStat?>().firstOrNull;
    final selectedTitle = selectedCategory == null ? 'Net surplus' : '${selectedCategory.name} total';
    final selectedValue = selectedCategory == null ? amountFormat.format(summary.netSurplus) : amountFormat.format(selectedCategory.amount);
    final selectedSubtitle = selectedCategory == null
        ? (summary.burnRate != null ? 'Burn rate ${percentFormat.format(summary.burnRate)}' : null)
        : '${selectedCategory.count} transactions';
    final selectedSubtitleWithHint = selectedSubtitle == null ? 'Long press to change' : '$selectedSubtitle · \nLong press to change';

    return PinnedSummaryLayout(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(periodLabel, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (summary.fileName != null) ...[
            const SizedBox(height: 4),
            Text(summary.fileName!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
      summary: CollapsibleSummarySection(
        title: 'Summary',
        subtitle:
            '${amountFormat.format(summary.totalRealExpenses)} expenses · '
            '${amountFormat.format(summary.netSurplus)} net',
        icon: Icons.summarize_outlined,
        accent: AppSemanticColors.expenses(context),
        metrics: [
          MetricCard(
            title: 'Real expenses',
            value: amountFormat.format(summary.totalRealExpenses),
            icon: Icons.arrow_downward,
            color: AppSemanticColors.expenses(context),
            subtitle: '${summary.realExpenseCount} transactions · excludes transfers',
            compact: true,
          ),
          MetricCard(
            title: 'Income received',
            value: amountFormat.format(summary.totalIncome),
            icon: Icons.arrow_upward,
            color: AppSemanticColors.accent(context),
            subtitle: 'Salary & cash in only',
            compact: true,
          ),
          MetricCard(
            title: selectedTitle,
            value: selectedValue,
            icon: Icons.savings_outlined,
            color: AppSemanticColors.result(context),
            subtitle: selectedSubtitleWithHint,
            compact: true,
            onLongPress: () => _showSummaryOptionPicker(context, subcategoryStats),
          ),
        ],
        prompt: AnalysisPromptPreviewCard(
          promptText: promptText,
          detailTitle: 'Expenses data for analysis',
          accent: AppSemanticColors.expenses(context),
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
          return _TransactionTile(transaction: tx, amountFormat: amountFormat, dateFormat: dateFormat);
        },
      ),
    );
  }

  Future<void> _showSummaryOptionPicker(BuildContext context, List<_ExpenseBucketStat> subcategoryStats) async {
    final options = <_SummaryOption>[
      const _SummaryOption(key: _netSurplusOption, label: 'Net surplus'),
      ...subcategoryStats.map((stat) => _SummaryOption(key: stat.name, label: '${stat.name} total')),
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Choose summary metric'), subtitle: Text('Long-press Net surplus card to open this list.')),
              ...options.map(
                (option) => ListTile(
                  title: Text(option.label),
                  trailing: option.key == _selectedSummaryOption
                      ? Icon(Icons.check_circle, color: AppSemanticColors.accent(context))
                      : const Icon(Icons.circle_outlined),
                  onTap: () => Navigator.of(context).pop(option.key),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    setState(() => _selectedSummaryOption = selected);
  }

  List<_ExpenseBucketStat> _realExpensesBySubcategory(List<CashewTransaction> transactions) {
    final totals = <String, double>{};
    final counts = <String, int>{};
    for (final tx in transactions) {
      if (!tx.isRealExpense) continue;
      final label = ExpensesSummary.subcategoryLabel(tx);
      totals[label] = (totals[label] ?? 0) + tx.amount.abs();
      counts[label] = (counts[label] ?? 0) + 1;
    }

    return totals.entries.map((entry) => _ExpenseBucketStat(name: entry.key, amount: entry.value, count: counts[entry.key] ?? 0)).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }
}

class _SummaryOption {
  const _SummaryOption({required this.key, required this.label});

  final String key;
  final String label;
}

class _ExpenseBucketStat {
  const _ExpenseBucketStat({required this.name, required this.amount, required this.count});

  final String name;
  final double amount;
  final int count;
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.amountFormat, required this.dateFormat});

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
        ? AppSemanticColors.accent(context)
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
                  Text(transaction.displayTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.account} · ${dateFormat.format(transaction.date)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (transaction.note != null && transaction.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        transaction.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            Text(
              isTransfer ? '—' : '${isIncome ? '+' : ''}${amountFormat.format(transaction.amount.abs())}',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: amountColor),
            ),
          ],
        ),
      ),
    );
  }
}
