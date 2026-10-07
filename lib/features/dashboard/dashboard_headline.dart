part of 'dashboard_charts.dart';

/// Change against the same span last month, shown as a small arrow chip.
class DashboardDelta {
  const DashboardDelta({
    required this.text,
    required this.rising,
    this.improved,
  });

  final String text;
  final bool rising;

  /// Whether the change is good (true), bad (false) or has no verdict (null).
  final bool? improved;

  /// Null when [change] is missing or too small to matter.
  static DashboardDelta? from(
    double? change,
    String Function(double magnitude) format, {
    bool? lowerIsBetter,
    double threshold = 0.05,
  }) {
    if (change == null || change.abs() < threshold) return null;
    final rising = change > 0;
    return DashboardDelta(
      text: format(change.abs()),
      rising: rising,
      improved: lowerIsBetter == null ? null : rising != lowerIsBetter,
    );
  }
}

class DashboardDeltaChip extends StatelessWidget {
  const DashboardDeltaChip({super.key, required this.delta});

  final DashboardDelta delta;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = switch (delta.improved) {
      true => palette.statusGood,
      false => palette.warning,
      null => palette.textMuted,
    };

    return Semantics(
      label:
          '${delta.rising ? 'Up' : 'Down'} ${delta.text} vs same days last month',
      excludeSemantics: true,
      child: Tooltip(
        message: 'vs same days last month',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: AppOpacity.medium),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                delta.rising
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 11,
                color: color,
              ),
              const SizedBox(width: 2),
              Text(
                delta.text,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One headline figure for the overview, linked to the card that explains it.
class DashboardHeadlineStat {
  const DashboardHeadlineStat({
    required this.label,
    required this.value,
    required this.color,
    required this.cardId,
    this.delta,
  });

  final String label;
  final String value;
  final Color color;
  final DashboardCardId cardId;
  final DashboardDelta? delta;
}

List<DashboardHeadlineStat> dashboardHeadlineStats(
  BuildContext context,
  DashboardViewData data,
) {
  String signed(double v, String unit, {int digits = 1}) =>
      '${v.toStringAsFixed(digits)}$unit';

  final stats = <DashboardHeadlineStat>[];

  final health = data.health;
  if (health != null) {
    stats.add(
      DashboardHeadlineStat(
        label: 'Sleep debt',
        value: signed(health.sleepDebtHours, ' h'),
        color: AppSemanticColors.health(context),
        cardId: DashboardCardId.health,
        delta: DashboardDelta.from(
          health.sleepDebtChangeHours,
          (v) => signed(v, ' h'),
          lowerIsBetter: true,
        ),
      ),
    );
  }

  final money = data.financial;
  if (money != null) {
    final budget = money.budgetConsumedPercent;
    stats.add(
      DashboardHeadlineStat(
        label: budget != null ? 'Budget used' : 'Spent',
        value: budget != null
            ? '${budget.toStringAsFixed(0)}%'
            : '${currencyPrefix(money.currency)}'
                  '${money.totalSpent.toStringAsFixed(0)}',
        color: AppSemanticColors.expenses(context),
        cardId: DashboardCardId.financial,
        delta: DashboardDelta.from(
          money.spentChangePercent,
          (v) => '${v.toStringAsFixed(0)}%',
          lowerIsBetter: true,
          threshold: 0.5,
        ),
      ),
    );
  }

  final mobility = data.mobility;
  if (mobility != null) {
    final tracksWork = mobility.workDays > 0;
    stats.add(
      DashboardHeadlineStat(
        label: tracksWork ? 'Late arrivals' : 'Ride distance',
        value: tracksWork
            ? '${mobility.lateArrivals} / ${mobility.workDays} d'
            : signed(mobility.motorcycleKm, ' km'),
        color: tracksWork && mobility.lateArrivals > 0
            ? context.palette.warning
            : AppSemanticColors.location(context),
        cardId: DashboardCardId.mobility,
        delta: tracksWork
            ? null
            : DashboardDelta.from(
                mobility.rideDistanceChangeKm,
                (v) => signed(v, ' km'),
              ),
      ),
    );
  }

  final gaming = data.gaming;
  if (gaming != null) {
    final hours = gaming.totalPlayHours;
    stats.add(
      DashboardHeadlineStat(
        label: 'Play time',
        value: hours >= 1 ? signed(hours, ' h') : '${(hours * 60).round()} m',
        color: AppSemanticColors.gameActivity(context),
        cardId: DashboardCardId.gaming,
        delta: DashboardDelta.from(
          gaming.playTimeChangeHours,
          (v) => signed(v, ' h'),
        ),
      ),
    );
  }

  final calendar = data.calendar;
  if (calendar != null) {
    stats.add(
      DashboardHeadlineStat(
        label: 'Major events',
        value: '${calendar.majorEventCount}',
        color: AppSemanticColors.calendar(context),
        cardId: DashboardCardId.calendar,
      ),
    );
  }

  return stats;
}

/// Two-column grid of headline figures; each tile jumps to its analysis card.
class DashboardHeadlineGrid extends StatelessWidget {
  const DashboardHeadlineGrid({
    super.key,
    required this.stats,
    required this.onOpen,
  });

  final List<DashboardHeadlineStat> stats;
  final ValueChanged<DashboardCardId> onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.sm;
        final tileWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final stat in stats)
              SizedBox(
                width: tileWidth,
                child: Semantics(
                  button: true,
                  label: '${stat.label}: ${stat.value}. Show details.',
                  excludeSemantics: true,
                  child: Material(
                    color: stat.color.withValues(alpha: AppOpacity.subtle),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      onTap: () => onOpen(stat.cardId),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stat.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: palette.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      stat.value,
                                      maxLines: 1,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: stat.color,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                    ),
                                  ),
                                ),
                                if (stat.delta != null) ...[
                                  const SizedBox(width: 6),
                                  DashboardDeltaChip(delta: stat.delta!),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
