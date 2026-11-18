part of 'location_screen.dart';

class _LocationBody extends StatelessWidget {
  const _LocationBody({
    required this.summary,
    required this.motorcycleTrips,
    required this.period,
    required this.workArrivalStats,
    required this.leaveDays,
    required this.workAddress,
    required this.workHours,
    required this.weekendDays,
    required this.insights,
    required this.profile,
    this.fuel,
  });

  final LocationSummary summary;
  final List<TimelineActivity> motorcycleTrips;
  final AnalysisPeriod period;
  final WorkArrivalStats workArrivalStats;
  final Map<DateTime, LeaveType> leaveDays;
  final String workAddress;
  final String workHours;
  final List<int> weekendDays;
  final MobilityFuelSummary? fuel;
  final LocationInsights insights;
  final LocationProfile profile;

  @override
  Widget build(BuildContext context) {
    final decimal = NumberFormat.decimalPattern();
    final accent = AppSemanticColors.mobility(context);

    final motorcycleKm = summary.periodMotorcycleDistanceMeters / 1000;
    final totalKm = summary.periodTotalDistanceMeters / 1000;
    final leadsWithMotorcycle = motorcycleKm > 0;
    final headlineKm = leadsWithMotorcycle ? motorcycleKm : totalKm;

    final weekendTrips = weekendDays.isEmpty
        ? const <TimelineActivity>[]
        : summary.periodMotorcycleActivitiesOnWeekendDays(weekendDays);
    final weekendKm =
        weekendTrips.fold(0.0, (sum, trip) => sum + trip.distanceMeters) / 1000;

    final groups = groupByDay(motorcycleTrips, (t) => t.startTime.toLocal());

    return CategoryScroll(
      slivers: [
        categoryBox(
          CategoryHero(
            accent: accent,
            icon: Icons.two_wheeler_rounded,
            label: leadsWithMotorcycle ? 'By motorcycle' : 'Distance travelled',
            value: headlineKm.toStringAsFixed(1),
            unit: 'km',
            caption: leadsWithMotorcycle
                ? '${decimal.format(motorcycleTrips.length)} trips'
                : '${decimal.format(summary.activities.length)} activities',
            footnote: period.dataRangeLabel,
            stats: [
              if (leadsWithMotorcycle)
                HeroStat(
                  'Travel time',
                  formatTravelDuration(summary.periodMotorcycleTravelTime),
                ),
              if (weekendDays.isNotEmpty)
                HeroStat('Weekend rides', '${weekendKm.toStringAsFixed(1)} km'),
              if (fuel != null && fuel!.refuelCount > 0)
                HeroStat(
                  'Fuel spend',
                  '${currencyPrefix(fuel!.currency)}'
                      '${decimal.format(fuel!.totalSpend.round())}',
                ),
            ],
          ),
        ),
        if (insights.commute.hasData)
          categoryBox(
            CommutePanel(
              commute: insights.commute,
              profile: profile,
              accent: accent,
            ),
          ),
        if (workArrivalStats.hasWorkVisits && workArrivalStats.hasLateThreshold)
          categoryBox(
            _WorkArrivalsPanel(
              stats: workArrivalStats,
              month: period.dataMonthStart,
              leaveDays: leaveDays,
              accent: accent,
            ),
          ),
        categoryBox(const CategoryTitle('Trips'), bottom: AppSpacing.xs),
        if (groups.isEmpty)
          categoryBox(
            Text(
              'No motorcycle trips in this period.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.palette.textMuted),
            ),
          )
        else
          categoryList(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final km =
                  group.value.fold(0.0, (sum, t) => sum + t.distanceMeters) /
                  1000;
              return DayGroup(
                date: group.key,
                accent: accent,
                total: '${km.toStringAsFixed(1)} km',
                children: [
                  for (final trip in group.value) _TripRow(trip: trip),
                ],
              );
            },
          ),
        categoryBox(
          AnalysisDataLink(
            promptText: summary.toAnalysisPromptText(
              dataMonthStart: period.dataMonthStart,
              dataMonthEnd: period.dataMonthEnd,
              workAddress: workAddress,
              workHours: workHours,
              weekendDays: weekendDays,
              fuel: fuel,
            ),
            title: 'Location data summary',
            accent: accent,
            icon: Icons.route_outlined,
          ),
        ),
      ],
    );
  }
}
