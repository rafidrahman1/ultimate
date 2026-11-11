part of 'expenses_screen.dart';

class _ExpensesBody extends StatefulWidget {
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
  State<_ExpensesBody> createState() => _ExpensesBodyState();
}

class _ExpensesBodyState extends State<_ExpensesBody> {
  ExpensesTab _tab = ExpensesTab.overview;

  ExpenseInsights get insights => widget.insights;
  ExpensesSummary get summary => widget.summary;
  List<CashewTransaction> get periodTransactions => widget.periodTransactions;
  Set<String> get excludedCategories => widget.excludedCategories;
  DateTime get monthStart => widget.monthStart;
  double? get budget => widget.budget;

  int _daysElapsed() {
    final projected = insights.projection?.daysElapsed;
    if (projected != null) return projected;
    final now = clock.now();
    final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final current =
        now.year == monthStart.year && now.month == monthStart.month;
    return current ? now.day : daysInMonth;
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppSemanticColors.expenses(context);
    final prefix = currencyPrefix(summary.currency);
    final money = NumberFormat.currency(symbol: prefix, decimalDigits: 0);
    final moneyExact = NumberFormat.currency(symbol: prefix, decimalDigits: 2);
    final percent = NumberFormat.decimalPercentPattern(decimalDigits: 0);

    final spent = summary.totalRealExpenses;
    final daysElapsed = _daysElapsed();
    final days = buildDayBars([
      for (final t in summary.transactions)
        if (t.isRealExpense) (date: t.date, value: t.amount.abs()),
    ], monthStart);
    final buckets = _realExpensesBySubcategory(summary.transactions);
    final categoryItems = [
      for (final b in buckets) (label: b.name, value: b.amount),
    ];
    final categories = [
      for (final stat in buckets)
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
    final projected = insights.projection?.projected;
    final hasBudget = budget != null && budget! > 0;

    final overview = <Widget>[
      categoryBox(
        SpendingHero(
          spent: spent,
          budget: budget,
          projected: projected,
          daysElapsed: daysElapsed,
          periodLabel: widget.periodLabel,
          money: money,
          footnoteStats: [
            (label: 'Income', value: money.format(summary.totalIncome)),
            (label: 'Net', value: money.format(summary.netSurplus)),
            if (burn != null) (label: 'Burn rate', value: percent.format(burn)),
            if (insights.savings.saved > 0)
              (label: 'Saved', value: money.format(insights.savings.saved)),
          ],
          caption: excludedCount == 0
              ? '${summary.realExpenseCount} transactions · excludes savings, loans and transfers'
              : '${summary.realExpenseCount} transactions · excludes savings, loans, transfers '
                    'and $excludedCount ${excludedCount == 1 ? 'category' : 'categories'}',
        ),
      ),
      categoryBox(
        SpendingByDay(
          days: days,
          average: daysElapsed > 0 && spent > 0 ? spent / daysElapsed : null,
          money: money,
          moneyExact: moneyExact,
        ),
      ),
      if (categoryItems.isNotEmpty)
        categoryBox(
          CategoryRanking(
            items: categoryItems,
            total: spent,
            money: money,
            limit: 4,
            onSeeAll: () => setState(() => _tab = ExpensesTab.categories),
          ),
        ),
      if (hasBudget && projected != null)
        categoryBox(
          BudgetOutlookCard(
            projected: projected,
            budget: budget!,
            money: money,
          ),
        ),
      if (periodTransactions.isNotEmpty)
        categoryBox(
          AppCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'RECENT TRANSACTIONS',
                        style: context.sectionLabel,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _tab = ExpensesTab.transactions),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                for (final tx in periodTransactions.take(3))
                  _TransactionRow(
                    transaction: tx,
                    money: moneyExact,
                    excluded: isExcluded(tx),
                  ),
              ],
            ),
          ),
        ),
    ];

    final transactions = <Widget>[
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
    ];

    final categoriesTab = <Widget>[
      if (categoryItems.isEmpty)
        categoryBox(
          Text(
            'No categorised spending this month.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.palette.textMuted),
          ),
        )
      else ...[
        categoryBox(
          CategoryRanking(
            items: categoryItems,
            total: spent,
            money: money,
            limit: categoryItems.length,
          ),
        ),
        categoryBox(
          CategoryPanel(
            title: 'Where it went',
            trailing: '${categories.length} categories',
            child: BreakdownBars(items: categories, color: accent),
          ),
        ),
      ],
    ];

    final insightsTab = <Widget>[
      if (summary.history.length >= 2)
        categoryBox(
          MonthlyTrendPanel(
            history: summary.history,
            typicalMonth: insights.typicalMonth,
            money: money,
          ),
        ),
      if (insights.corrections.suggestsMissedEntries)
        categoryBox(CorrectionsHint(stats: insights.corrections, money: money)),
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
      categoryBox(
        AnalysisDataLink(
          promptText: summary.toAnalysisPromptText(
            context: widget.expensePromptContext,
          ),
          title: 'Expenses data summary',
          accent: accent,
          icon: Icons.account_balance_wallet_outlined,
        ),
      ),
    ];

    return CategoryScroll(
      slivers: [
        categoryBox(
          ExpensesTabs(
            selected: _tab,
            onSelected: (t) => setState(() => _tab = t),
          ),
        ),
        ...switch (_tab) {
          ExpensesTab.overview => overview,
          ExpensesTab.transactions => transactions,
          ExpensesTab.categories => categoriesTab,
          ExpensesTab.insights => insightsTab,
        },
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
