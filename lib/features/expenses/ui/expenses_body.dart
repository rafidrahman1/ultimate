part of 'expenses_screen.dart';

class _ExpensesBody extends StatelessWidget {
  const _ExpensesBody({
    required this.insights,
    required this.summary,
    required this.periodTransactions,
    required this.excludedCategories,
    required this.periodLabel,
    required this.monthStart,
    required this.budget,
    required this.expensePromptContext,
  });

  final ExpenseInsights insights;
  final ExpensesSummary summary;

  /// Every transaction in the period, including excluded categories, so the
  /// list still shows them.
  final List<CashewTransaction> periodTransactions;
  final Set<String> excludedCategories;
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
    final groups = groupByDay(periodTransactions, (t) => t.date);
    bool isExcluded(CashewTransaction t) =>
        ExpensesSummary.isExcludedExpense(t, excludedCategories);
    final excludedCount = excludedCategories.length;
    final burn = summary.burnRate;

    return CategoryScroll(
      slivers: [
        categoryBox(
          CategoryHero(
            accent: accent,
            icon: Icons.account_balance_wallet_rounded,
            label: 'Real expenses',
            value: money.format(spent),
            caption: excludedCount == 0
                ? '${summary.realExpenseCount} transactions · excludes savings, loans and transfers'
                : '${summary.realExpenseCount} transactions · excludes savings, loans, transfers '
                      'and $excludedCount ${excludedCount == 1 ? 'category' : 'categories'}',
            footnote: periodLabel,
            visual: budget != null && budget! > 0
                ? _BudgetBar(spent: spent, budget: budget!, money: money)
                : null,
            stats: [
              HeroStat('Income', money.format(summary.totalIncome)),
              HeroStat('Net', money.format(summary.netSurplus)),
              if (burn != null) HeroStat('Burn rate', percent.format(burn)),
              if (insights.savings.saved > 0)
                HeroStat('Saved', money.format(insights.savings.saved)),
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
        if (summary.history.length >= 2)
          categoryBox(
            MonthlyTrendPanel(
              history: summary.history,
              typicalMonth: insights.typicalMonth,
              money: money,
            ),
          ),
        if (insights.corrections.suggestsMissedEntries)
          categoryBox(
            CorrectionsHint(stats: insights.corrections, money: money),
          ),
        if (insights.savings.hasActivity || summary.recurring.isNotEmpty)
          categoryBox(
            SavingsPanel(
              savings: insights.savings,
              recurring: summary.recurring,
              money: money,
            ),
          ),
        if (insights.loans.hasAny)
          categoryBox(DebtsPanel(loans: insights.loans, money: money)),
        if (insights.incomeMix.isNotEmpty)
          categoryBox(IncomeMixPanel(slices: insights.incomeMix, money: money)),
        if (insights.merchants.isNotEmpty)
          categoryBox(
            RepeatPlacesPanel(merchants: insights.merchants, money: money),
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
                .where((t) => t.isRealExpense && !isExcluded(t))
                .fold<double>(0, (sum, t) => sum + t.amount.abs());
            return DayGroup(
              date: group.key,
              accent: accent,
              total: dayTotal > 0 ? '-${moneyExact.format(dayTotal)}' : null,
              children: [
                for (final tx in group.value)
                  _TransactionRow(
                    transaction: tx,
                    money: moneyExact,
                    excluded: isExcluded(tx),
                  ),
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
