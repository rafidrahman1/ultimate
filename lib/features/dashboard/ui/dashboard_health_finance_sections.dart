part of 'dashboard_screen.dart';

class _HealthSection extends StatelessWidget {
  const _HealthSection({required this.section});

  final DashboardHealthAnalysis section;

  @override
  Widget build(BuildContext context) {
    final color = AppSemanticColors.health(context);

    return DashboardSectionCard(
      cardId: DashboardCardId.health,
      delta: DashboardDelta.from(
        section.sleepDebtChangeHours,
        (v) => '${v.toStringAsFixed(1)} h',
        lowerIsBetter: true,
      ),
      title: 'Sleep analysis',
      subtitle:
          '${section.nightsTracked} nights · ${section.nightsBelowTarget} below 7h target',
      icon: Icons.bedtime_rounded,
      accent: color,
      summary: DashboardLeadRow(
        percent: section.recoveryRatePercent,
        ringLabel: 'recovery',
        ringColor: AppSemanticColors.accent(context),
        metrics: [
          (
            label: 'Sleep debt',
            value: '${section.sleepDebtHours.toStringAsFixed(1)} h',
            color: color,
          ),
          (
            label: 'Bedtime σ',
            value: section.bedtimeStdDevMinutes != null
                ? '${section.bedtimeStdDevMinutes!.round()} m'
                : '—',
            color: color,
          ),
          if (section.recoveryRatePercent == null)
            (label: 'Recovery', value: '—', color: color),
        ],
      ),
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.clusters.isNotEmpty) ...[
            Text(
              'Short-sleep clusters',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            DashboardHorizontalBars(items: section.clusters, color: color),
            const SizedBox(height: 18),
          ],
          Text(
            'Daily sleep vs 7h target',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardColumnChart(
            items: section.dailySleep,
            color: color,
            targetLine: 7,
          ),
        ],
      ),
    );
  }
}

class _FinancialSection extends StatelessWidget {
  const _FinancialSection({required this.section});

  final DashboardFinancialAnalysis section;

  @override
  Widget build(BuildContext context) {
    final color = AppSemanticColors.expenses(context);
    final amountFormat = NumberFormat.currency(
      symbol: currencyPrefix(section.currency),
      decimalDigits: 0,
    );

    return DashboardSectionCard(
      cardId: DashboardCardId.financial,
      delta: DashboardDelta.from(
        section.spentChangePercent,
        (v) => '${v.toStringAsFixed(0)}%',
        lowerIsBetter: true,
        threshold: 0.5,
      ),
      title: 'Financial analysis',
      subtitle: section.topCategoryName != null
          ? 'Top category: ${section.topCategoryName}'
          : 'Budget and concentration metrics',
      icon: Icons.account_balance_wallet_rounded,
      accent: color,
      summary: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardLeadRow(
            percent: section.budgetConsumedPercent,
            ringLabel: 'of budget',
            ringColor: color,
            metrics: [
              (
                label: 'Income used',
                value: section.incomeUtilizationPercent != null
                    ? '${section.incomeUtilizationPercent!.toStringAsFixed(0)}%'
                    : '—',
                color: AppSemanticColors.accent(context),
              ),
              (
                label: 'Net',
                value: amountFormat.format(section.netSurplus),
                color: AppSemanticColors.result(context),
              ),
              if (section.budgetConsumedPercent == null)
                (label: 'Budget used', value: '—', color: color),
            ],
          ),
          if (section.topCategorySharePercent != null ||
              section.top3CategorySharePercent != null) ...[
            const SizedBox(height: 18),
            DashboardMetricRow(
              metrics: [
                (
                  label: 'Top category',
                  value: section.topCategorySharePercent != null
                      ? '${section.topCategorySharePercent!.toStringAsFixed(0)}%'
                      : '—',
                  color: color,
                ),
                (
                  label: 'Top 3 share',
                  value: section.top3CategorySharePercent != null
                      ? '${section.top3CategorySharePercent!.toStringAsFixed(0)}%'
                      : '—',
                  color: color,
                ),
                (
                  label: 'Burn rate',
                  value: section.burnRatePercent != null
                      ? '${section.burnRatePercent!.toStringAsFixed(0)}%'
                      : '—',
                  color: AppSemanticColors.mobility(context),
                ),
              ],
            ),
          ],
        ],
      ),
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Category concentration',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          DashboardHorizontalBars(
            items: section.categoryConcentration,
            color: color,
          ),
        ],
      ),
    );
  }
}
