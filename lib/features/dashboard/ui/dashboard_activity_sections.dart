part of 'dashboard_screen.dart';

class _MobilitySection extends StatelessWidget {
  const _MobilitySection({required this.section});

  final DashboardMobilityAnalysis section;

  @override
  Widget build(BuildContext context) {
    final color = AppSemanticColors.location(context);
    final rideChange = section.rideDistanceChangeKm;

    return DashboardSectionCard(
      cardId: DashboardCardId.mobility,
      delta: DashboardDelta.from(
        rideChange,
        (v) => '${v.toStringAsFixed(1)} km',
      ),
      title: 'Mobility analysis',
      subtitle:
          '${section.motorcycleKm.toStringAsFixed(1)} km by motorcycle · '
          '${section.workDays} work days',
      icon: Icons.route_rounded,
      accent: color,
      summary: DashboardLeadRow(
        percent: section.lateArrivalRatePercent,
        ringLabel: 'late rate',
        ringColor: context.palette.warning,
        metrics: [
          (label: 'Late days', value: '${section.lateArrivals}', color: color),
          (
            label: 'Avg delay',
            value: section.averageDelayMinutes != null
                ? '${section.averageDelayMinutes!.round()} m'
                : '—',
            color: AppSemanticColors.accent(context),
          ),
          if (section.lateArrivalRatePercent == null)
            (label: 'Late rate', value: '—', color: color),
        ],
      ),
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.fuelSpend != null) ...[
            DashboardMetricRow(
              metrics: [
                (
                  label: 'Fuel spend',
                  value: section.fuelSpend!.toStringAsFixed(0),
                  color: AppSemanticColors.expenses(context),
                ),
                (
                  label: 'Refuels',
                  value: '${section.fuelRefuelCount ?? 0}',
                  color: color,
                ),
                (
                  label: 'Travel time',
                  value: '${section.travelTimeHours.toStringAsFixed(1)} h',
                  color: color,
                ),
              ],
            ),
          ],
          if (section.fuelLitres != null) ...[
            if (section.fuelSpend != null) const SizedBox(height: 16),
            DashboardMetricRow(
              metrics: [
                (
                  label: 'Fuel bought',
                  value: '${section.fuelLitres!.toStringAsFixed(1)} L',
                  color: color,
                ),
                (
                  label: 'Avg price',
                  value: section.fuelRatePerLitre != null
                      ? '${currencyPrefix(section.fuelCurrency)}'
                            '${section.fuelRatePerLitre!.toStringAsFixed(1)}/L'
                      : '—',
                  color: AppSemanticColors.expenses(context),
                ),
              ],
            ),
            if ((section.fuelPricedRefuelCount ?? 0) <
                (section.fuelRefuelCount ?? 0)) ...[
              const SizedBox(height: 8),
              Text(
                'Litres from ${section.fuelPricedRefuelCount} of '
                '${section.fuelRefuelCount} refuels — add a rate like '
                '"125/L" to the other descriptions.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
          if (section.rideDistanceKm != null) ...[
            if (section.fuelSpend != null || section.fuelLitres != null)
              const SizedBox(height: 16),
            Text(
              rideChange != null
                  ? 'Motorcycle distance: ${section.rideDistanceKm!.toStringAsFixed(1)} km '
                        '(${rideChange >= 0 ? '+' : ''}${rideChange.toStringAsFixed(1)} km vs prior month)'
                  : 'Motorcycle distance: ${section.rideDistanceKm!.toStringAsFixed(1)} km',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (section.byTransport.isNotEmpty) ...[
            if (section.fuelSpend != null ||
                section.fuelLitres != null ||
                section.rideDistanceKm != null)
              const SizedBox(height: 18),
            Text(
              'Distance by mode',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DashboardHorizontalBars(items: section.byTransport, color: color),
          ],
        ],
      ),
    );
  }
}

class _GamingSection extends StatelessWidget {
  const _GamingSection({required this.section});

  final DashboardGamingAnalysis section;

  @override
  Widget build(BuildContext context) {
    final color = AppSemanticColors.gameActivity(context);
    final hoursLabel = section.totalPlayHours >= 1
        ? '${section.totalPlayHours.toStringAsFixed(1)} h'
        : '${(section.totalPlayHours * 60).round()} m';

    return DashboardSectionCard(
      cardId: DashboardCardId.gaming,
      delta: DashboardDelta.from(
        section.playTimeChangeHours,
        (v) => '${v.toStringAsFixed(1)} h',
      ),
      title: 'Gaming trend',
      subtitle: section.sessionChange != null
          ? '$hoursLabel · ${section.sessionChange! >= 0 ? '+' : ''}${section.sessionChange} sessions vs prior month'
          : '$hoursLabel · ${section.sessionCount} sessions',
      icon: Icons.sports_esports_rounded,
      accent: color,
      summary: DashboardMetricRow(
        metrics: [
          (label: 'Play time', value: hoursLabel, color: color),
          (label: 'Sessions', value: '${section.sessionCount}', color: color),
          (
            label: 'Δ play time',
            value: section.playTimeChangeHours != null
                ? '${section.playTimeChangeHours! >= 0 ? '+' : ''}${section.playTimeChangeHours!.toStringAsFixed(1)} h'
                : '—',
            color: AppSemanticColors.accent(context),
          ),
        ],
      ),
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Time by game',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DashboardHorizontalBars(items: section.byGame, color: color),
        ],
      ),
    );
  }
}

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({required this.section});

  final DashboardCalendarAnalysis section;

  @override
  Widget build(BuildContext context) {
    final color = AppSemanticColors.calendar(context);

    return DashboardSectionCard(
      cardId: DashboardCardId.calendar,
      title: 'Calendar load',
      subtitle:
          '${section.majorEventCount} major events · '
          '${section.expenseLinkedEventCount} expense-linked',
      icon: Icons.calendar_month_rounded,
      accent: color,
      summary: DashboardMetricRow(
        metrics: [
          (label: 'Major', value: '${section.majorEventCount}', color: color),
          (label: 'Holidays', value: '${section.holidayCount}', color: color),
          (
            label: 'Expense-linked',
            value: '${section.expenseLinkedEventCount}',
            color: AppSemanticColors.expenses(context),
          ),
        ],
      ),
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Events by weekday',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DashboardColumnChart(
            items: section.byWeekday,
            color: color,
            height: 140,
          ),
        ],
      ),
    );
  }
}
