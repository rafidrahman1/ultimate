part of 'dashboard_tiles.dart';

/// Shared tile surface: title with a chevron, content below, no border.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.onTap,
    required this.child,
    this.padding = AppSpacing.xl,
  });

  final double padding;
  final String title;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '$title. Show details',
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.cardLarge + 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: palette.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero tile: big average sleep, change vs last month, area chart.
class _SleepTile extends StatelessWidget {
  const _SleepTile({
    required this.section,
    required this.stat,
    required this.onTap,
  });

  final DashboardHealthAnalysis section;
  final HomeTileStat? stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final color = AppSemanticColors.health(context);
    final delta = DashboardDelta.from(
      section.sleepDebtChangeHours,
      (v) => '${v.toStringAsFixed(1)} h',
      lowerIsBetter: true,
    );
    final deltaColor = switch (delta?.improved) {
      true => palette.statusGood,
      false => palette.warning,
      _ => palette.textMuted,
    };
    final series = stat?.series;

    return _Tile(
      title: 'Sleep',
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    stat?.value ?? '—',
                    style: context.statDisplay.copyWith(fontSize: 34),
                  ),
                ),
                Text(
                  'avg sleep · ${section.nightsTracked} nights',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (delta != null)
                  Row(
                    children: [
                      Icon(
                        delta.rising
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 16,
                        color: deltaColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${delta.text} ',
                                style: TextStyle(
                                  color: deltaColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: 'sleep debt vs last month',
                                style: TextStyle(color: palette.textMuted),
                              ),
                            ],
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '${section.nightsBelowTarget} below 7 h target',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (series != null) ...[
            const SizedBox(width: AppSpacing.md),
            Sparkline(values: series, color: color, width: 120, height: 64),
          ],
        ],
      ),
    );
  }
}

/// Expenses tile: ranked categories on the left, donut with the total.
class _ExpensesTile extends StatelessWidget {
  const _ExpensesTile({required this.section, required this.onTap});

  final DashboardFinancialAnalysis section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final cats = section.categoryConcentration;
    final colors = [
      AppSemanticColors.expenses(context),
      AppSemanticColors.location(context),
      AppSemanticColors.health(context),
      AppSemanticColors.calendar(context),
      AppSemanticColors.gameActivity(context),
    ];
    final prefix = currencyPrefix(section.currency);
    final total =
        '$prefix${NumberFormat.decimalPattern().format(section.totalSpent.round())}';
    final shown = cats.take(4).toList();
    final more = cats.length - shown.length;

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors[i % colors.length],
                  ),
                  child: const SizedBox.square(dimension: 10),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    shown[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      shown[i].displayValue,
                      maxLines: 1,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (more > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ $more more',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ),
      ],
    );

    final donut = DonutChart(
      values: [for (final c in shown) c.value],
      colors: colors,
      size: 116,
      center: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total',
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            Text(
              total,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );

    return _Tile(
      title: 'Expenses',
      onTap: onTap,
      child: shown.isEmpty
          ? Text(total, style: context.statDisplay.copyWith(fontSize: 30))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: list),
                const SizedBox(width: AppSpacing.lg),
                donut,
              ],
            ),
    );
  }
}

class _StatRow {
  const _StatRow(this.icon, this.value, this.unit, this.color);

  final IconData icon;
  final String value;
  final String unit;
  final Color color;
}

/// Compact tile of stacked icon + value + unit rows.
class _StatRowsTile extends StatelessWidget {
  const _StatRowsTile({
    required this.title,
    required this.rows,
    required this.onTap,
  });

  final String title;
  final List<_StatRow> rows;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return _Tile(
      title: title,
      onTap: onTap,
      padding: AppSpacing.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(r.icon, size: 20, color: r.color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: r.value,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: ' ${r.unit}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
