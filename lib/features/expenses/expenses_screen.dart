import 'dart:async';

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
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/pinned_summary_layout.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/calendar_settings_service.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_category_settings_service.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/core/formatting.dart';
import 'package:personal/shared/widgets/pull_to_refresh.dart';

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
    await _loadFromDriveIfNeeded();
  }

  /// Auto-load from Google Drive only when nothing is cached yet.
  Future<void> _loadFromDriveIfNeeded() async {
    if (ref.read(expensesSummaryProvider).transactions.isNotEmpty) return;
    await _loadFromDrive();
  }

  bool get _isGoogleConnected {
    final settings = ref.read(calendarSettingsProvider).valueOrNull;
    final authUser = ref.read(authStateProvider).valueOrNull;
    return (settings?.isConnected ?? false) || authUser != null;
  }

  Future<void> _loadFromDrive({bool interactive = false}) async {
    if (!_isGoogleConnected) return;

    final hasData = ref.read(expensesSummaryProvider).transactions.isNotEmpty;
    setState(() {
      if (!hasData) _loading = true;
      _loadError = null;
    });

    try {
      await ref
          .read(expensesSummaryProvider.notifier)
          .loadFromGoogleDrive(interactiveSignIn: interactive);
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
    final rawPeriodSummary = rawSummary.forAnalysisPeriod(period);
    final excludedCategories = ref.watch(excludedExpenseCategoriesProvider);
    final settings = ref.watch(calendarSettingsProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final isConnected = (settings?.isConnected ?? false) || authUser != null;
    final profile = ref.watch(promptConfigProvider).valueOrNull;
    final expensePromptContext = ExpensePromptContext(
      period: period,
      sourceSummary: ref.watch(expensesHistoryProvider),
      monthlyIncomeBdt: profile?.analysisMonthlyIncomeBdt,
      monthlyBudgetBdt: profile?.monthlyBudgetBdt,
      financialInstruction: profile?.financialInstruction ?? '',
    );

    ref.listen(authStateProvider, (previous, next) {
      final wasConnected = previous?.valueOrNull != null;
      final isNowConnected = next.valueOrNull != null;
      if (!wasConnected && isNowConnected) {
        unawaited(_loadFromDrive(interactive: true));
      }
    });

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Expenses',
        extraActions: [
          if (rawSummary.transactions.isNotEmpty)
            AppBarCircularAction(
              icon: excludedCategories.isEmpty
                  ? Icons.filter_list
                  : Icons.filter_list_alt,
              onPressed: () => _showCategoryPicker(context, rawSummary),
            ),
          if (rawSummary.transactions.isNotEmpty)
            AppBarCircularAction(
              icon: Icons.close,
              onPressed: () =>
                  ref.read(expensesSummaryProvider.notifier).clear(),
            ),
          AppBarCircularAction(
            icon: Icons.refresh,
            onPressed: isConnected && !_loading
                ? () => _loadFromDrive(interactive: true)
                : null,
          ),
        ],
      ),
      body: PullToRefresh(
        onRefresh: isConnected ? () => _loadFromDrive(interactive: true) : null,
        child: _loading
            ? const PinnedSummarySkeleton(
                metricCount: 3,
                listItemStyle: PinnedSummaryListItemStyle.detailed,
              )
            : rawPeriodSummary.transactions.isEmpty
            ? StatusMessage(
                icon: Icons.account_balance_wallet_outlined,
                title: rawSummary.transactions.isEmpty
                    ? 'No expenses loaded'
                    : 'No expenses in ${period.dataRangeLabel}',
                subtitle:
                    _loadError ??
                    (isConnected
                        ? 'No transactions found in Google Drive Cashew/outbox.csv. '
                              'Tap Sync after Cashew updates the file.'
                        : 'Sign in with Google to load Cashew/outbox.csv from Drive, '
                              'or import a CSV manually.'),
                action: isConnected
                    ? null
                    : FilledButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.calendarSettings,
                        ),
                        child: const Text('Connect Google'),
                      ),
              )
            : _ExpensesBody(
                summary: summary,
                periodTransactions: rawPeriodSummary.sortedByDate,
                excludedCategories: excludedCategories,
                periodLabel: period.dataRangeLabel,
                expensePromptContext: expensePromptContext,
              ),
      ),
      floatingActionButton: isConnected
          ? FloatingActionButton.extended(
              onPressed: _loading
                  ? null
                  : () => _loadFromDrive(interactive: true),
              icon: const Icon(Icons.sync),
              label: const Text('Sync'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _importCsv(context),
              icon: const Icon(Icons.upload_file),
              label: const Text('Import CSV'),
            ),
    );
  }

  Future<void> _showCategoryPicker(
    BuildContext context,
    ExpensesSummary rawSummary,
  ) async {
    final current = ref.read(excludedExpenseCategoriesProvider);
    // Keep excluded categories listed even if they no longer appear in the
    // import, so they can still be re-included.
    final categories = {...rawSummary.expenseCategoryNames, ...current}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _CategoryPickerSheet(
        categories: categories,
        initiallyExcluded: current,
      ),
    );
    if (result == null || !mounted) return;
    await ref
        .read(excludedExpenseCategoriesProvider.notifier)
        .setExcluded(result);
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
  const _ExpensesBody({
    required this.summary,
    required this.periodTransactions,
    required this.excludedCategories,
    required this.periodLabel,
    required this.expensePromptContext,
  });

  final ExpensesSummary summary;
  final List<CashewTransaction> periodTransactions;
  final Set<String> excludedCategories;
  final String periodLabel;
  final ExpensePromptContext expensePromptContext;

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
    final amountFormat = NumberFormat.currency(
      symbol: currencyPrefix(currency),
      decimalDigits: 2,
    );
    final percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 2);
    final dateFormat = DateFormat('d MMM yyyy');
    final transactions = widget.periodTransactions;
    final promptText = summary.toAnalysisPromptText(
      context: widget.expensePromptContext,
    );
    final subcategoryStats = _realExpensesBySubcategory(summary.transactions);

    final selectedCategory = _selectedSummaryOption == _netSurplusOption
        ? null
        : subcategoryStats
              .where((stat) => stat.name == _selectedSummaryOption)
              .cast<_ExpenseBucketStat?>()
              .firstOrNull;
    final selectedTitle = selectedCategory == null
        ? 'Net surplus'
        : '${selectedCategory.name} total';
    final selectedValue = selectedCategory == null
        ? amountFormat.format(summary.netSurplus)
        : amountFormat.format(selectedCategory.amount);
    final selectedSubtitle = selectedCategory == null
        ? (summary.burnRate != null
              ? 'Burn rate ${percentFormat.format(summary.burnRate)}'
              : null)
        : '${selectedCategory.count} transactions';
    final selectedSubtitleWithHint = selectedSubtitle == null
        ? 'Long press to change'
        : '$selectedSubtitle · \nLong press to change';

    return PinnedSummaryLayout(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            periodLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (summary.fileName != null) ...[
            const SizedBox(height: 4),
            Text(
              summary.fileName!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
            subtitle: widget.excludedCategories.isEmpty
                ? '${summary.realExpenseCount} transactions · excludes transfers'
                : '${summary.realExpenseCount} transactions · '
                      '${widget.excludedCategories.length} '
                      '${widget.excludedCategories.length == 1 ? 'category' : 'categories'} excluded',
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
            onLongPress: () =>
                _showSummaryOptionPicker(context, subcategoryStats),
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
          return _TransactionTile(
            transaction: tx,
            excluded: ExpensesSummary.isExcludedExpense(
              tx,
              widget.excludedCategories,
            ),
            amountFormat: amountFormat,
            dateFormat: dateFormat,
          );
        },
      ),
    );
  }

  Future<void> _showSummaryOptionPicker(
    BuildContext context,
    List<_ExpenseBucketStat> subcategoryStats,
  ) async {
    final options = <_SummaryOption>[
      const _SummaryOption(key: _netSurplusOption, label: 'Net surplus'),
      ...subcategoryStats.map(
        (stat) => _SummaryOption(key: stat.name, label: '${stat.name} total'),
      ),
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Choose summary metric'),
                subtitle: Text(
                  'Long-press Net surplus card to open this list.',
                ),
              ),
              ...options.map(
                (option) => ListTile(
                  title: Text(option.label),
                  trailing: option.key == _selectedSummaryOption
                      ? Icon(
                          Icons.check_circle,
                          color: AppSemanticColors.accent(context),
                        )
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

  List<_ExpenseBucketStat> _realExpensesBySubcategory(
    List<CashewTransaction> transactions,
  ) {
    final totals = <String, double>{};
    final counts = <String, int>{};
    for (final tx in transactions) {
      if (!tx.isRealExpense) continue;
      final label = ExpensesSummary.subcategoryLabel(tx);
      totals[label] = (totals[label] ?? 0) + tx.amount.abs();
      counts[label] = (counts[label] ?? 0) + 1;
    }

    return totals.entries
        .map(
          (entry) => _ExpenseBucketStat(
            name: entry.key,
            amount: entry.value,
            count: counts[entry.key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.initiallyExcluded,
  });

  final List<String> categories;
  final Set<String> initiallyExcluded;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late final Set<String> _excluded = {...widget.initiallyExcluded};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allIncluded = _excluded.isEmpty;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: const Text('Categories counted as expenses'),
              subtitle: const Text(
                'Unchecked categories are left out of totals, charts, '
                'and AI analysis.',
              ),
              trailing: TextButton(
                onPressed: () => setState(() {
                  if (allIncluded) {
                    _excluded.addAll(widget.categories);
                  } else {
                    _excluded.clear();
                  }
                }),
                child: Text(allIncluded ? 'None' : 'All'),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: widget.categories.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No expense categories in this import.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final category in widget.categories)
                          CheckboxListTile(
                            title: Text(category),
                            value: !_excluded.contains(category),
                            onChanged: (included) => setState(() {
                              if (included ?? false) {
                                _excluded.remove(category);
                              } else {
                                _excluded.add(category);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_excluded),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryOption {
  const _SummaryOption({required this.key, required this.label});

  final String key;
  final String label;
}

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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.amountFormat,
    required this.dateFormat,
    this.excluded = false,
  });

  final CashewTransaction transaction;
  final bool excluded;
  final NumberFormat amountFormat;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTransfer = transaction.isBalanceCorrection;
    final isIncome = transaction.isRealIncome;
    final amountColor = isTransfer || excluded
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
                  Text(
                    transaction.displayTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.account} · ${dateFormat.format(transaction.date)}'
                    '${excluded ? ' · Excluded' : ''}',
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
