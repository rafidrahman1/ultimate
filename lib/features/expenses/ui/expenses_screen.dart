import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal/app/router.dart';
import 'package:personal/core/formatting.dart';
import 'package:personal/core/period/analysis_month_settings_service.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/data/calendar_settings_service.dart';
import 'package:personal/features/expenses/analysis/expense_insights.dart';
import 'package:personal/features/expenses/analysis/expense_prompt_builder.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/expenses/data/expense_category_settings_service.dart';
import 'package:personal/features/expenses/data/expenses_service.dart';
import 'package:personal/features/expenses/ui/expense_panels.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/category/category_hero.dart';
import 'package:personal/shared/widgets/category/category_scroll.dart';
import 'package:personal/shared/widgets/category/day_bars.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';
import 'package:personal/shared/widgets/pull_to_refresh.dart';
import 'package:personal/shared/widgets/status_message.dart';

part 'expense_budget_rows.dart';
part 'expense_category_picker_sheet.dart';
part 'expenses_body.dart';

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

  /// Auto-load from Google Drive when nothing is cached, or when the cache
  /// predates loans and recurring entries. A failed refresh keeps the cache.
  Future<void> _loadFromDriveIfNeeded() async {
    final current = ref.read(expensesSummaryProvider);
    if (current.transactions.isNotEmpty && !current.isLegacyCache) return;
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
            ? const CardListSkeleton(cardHeights: [210, 200, 72, 72, 72])
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
                insights: computeExpenseInsights(
                  summary,
                  periodStart: period.dataMonthStart,
                ),
                summary: summary,
                periodTransactions: rawPeriodSummary.sortedByDate,
                excludedCategories: excludedCategories,
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
