import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/app/router.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/category/category_hero.dart';
import 'package:personal/shared/widgets/category/category_scroll.dart';
import 'package:personal/shared/widgets/category/day_bars.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/calendar_settings_service.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
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
    final settings = ref.watch(calendarSettingsProvider).valueOrNull;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final isConnected = (settings?.isConnected ?? false) || authUser != null;
    final profile = ref.watch(promptConfigProvider).valueOrNull;
    final expensePromptContext = ExpensePromptContext(
      period: period,
      sourceSummary: rawSummary,
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
            : summary.transactions.isEmpty
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
                periodLabel: period.dataRangeLabel,
                monthStart: period.dataMonthStart,
                budget: double.tryParse(
                  (profile?.monthlyBudgetBdt ?? '').replaceAll(',', '').trim(),
                ),
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

class _ExpensesBody extends StatelessWidget {
  const _ExpensesBody({
    required this.summary,
    required this.periodLabel,
    required this.monthStart,
    required this.budget,
    required this.expensePromptContext,
  });

  final ExpensesSummary summary;
  final String periodLabel;
  final DateTime monthStart;
  final double? budget;
  final ExpensePromptContext expensePromptContext;

  @override
  Widget build(BuildContext context) {
    final accent = AppSemanticColors.expenses(context);
    final prefix = currencyPrefix(summary.currency);
    final money = NumberFormat.currency(symbol: prefix, decimalDigits: 0);
    final moneyExact = NumberFormat.currency(symbol: prefix, decimalDigits: 2);
    final percent = NumberFormat.decimalPercentPattern(decimalDigits: 0);

    final spent = summary.totalRealExpenses;
    final days = buildDayBars([
      for (final t in summary.transactions)
        if (t.isRealExpense) (date: t.date, value: t.amount.abs()),
    ], monthStart);
    final categories = [
      for (final stat in _realExpensesBySubcategory(summary.transactions))
        (
          label: stat.name,
          value: stat.amount,
          display: money.format(stat.amount),
        ),
    ];
    final groups = groupByDay(summary.sortedByDate, (t) => t.date);
    final burn = summary.burnRate;

    return CategoryScroll(
      slivers: [
        categoryBox(
          CategoryHero(
            accent: accent,
            icon: Icons.account_balance_wallet_rounded,
            label: 'Real expenses',
            value: money.format(spent),
            caption:
                '${summary.realExpenseCount} transactions · excludes transfers',
            footnote: periodLabel,
            visual: budget != null && budget! > 0
                ? _BudgetBar(spent: spent, budget: budget!, money: money)
                : null,
            stats: [
              HeroStat('Income', money.format(summary.totalIncome)),
              HeroStat('Net', money.format(summary.netSurplus)),
              if (burn != null) HeroStat('Burn rate', percent.format(burn)),
            ],
          ),
        ),
        categoryBox(
          CategoryPanel(
            title: 'Spending by day',
            child: DayBars(
              data: days,
              color: accent,
              format: moneyExact.format,
              emptyLabel: 'No spending recorded this month',
            ),
          ),
        ),
        if (categories.isNotEmpty)
          categoryBox(
            CategoryPanel(
              title: 'Where it went',
              trailing: '${categories.length} categories',
              child: BreakdownBars(items: categories, color: accent),
            ),
          ),
        categoryBox(const CategoryTitle('Transactions'), bottom: AppSpacing.xs),
        categoryList(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final dayTotal = group.value
                .where((t) => t.isRealExpense)
                .fold<double>(0, (sum, t) => sum + t.amount.abs());
            return DayGroup(
              date: group.key,
              accent: accent,
              total: dayTotal > 0 ? '-${moneyExact.format(dayTotal)}' : null,
              children: [
                for (final tx in group.value)
                  _TransactionRow(transaction: tx, money: moneyExact),
              ],
            );
          },
        ),
        categoryBox(
          AnalysisDataLink(
            promptText: summary.toAnalysisPromptText(
              context: expensePromptContext,
            ),
            title: 'Expenses data for analysis',
            accent: accent,
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
      ],
    );
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
  const _TransactionRow({required this.transaction, required this.money});

  final CashewTransaction transaction;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isTransfer = transaction.isBalanceCorrection;
    final isIncome = transaction.isRealIncome;
    final accent = AppSemanticColors.expenses(context);
    final income = AppSemanticColors.accent(context);
    final amount = money.format(transaction.amount.abs());

    return CategoryRow(
      icon: isTransfer
          ? Icons.swap_horiz_rounded
          : isIncome
          ? Icons.south_west_rounded
          : Icons.north_east_rounded,
      accent: isIncome ? income : accent,
      muted: isTransfer,
      title: transaction.displayTitle,
      subtitle: transaction.account,
      detail: transaction.note,
      trailing: isTransfer ? '—' : '${isIncome ? '+' : '-'}$amount',
      trailingColor: isIncome ? income : palette.textPrimary,
    );
  }
}
