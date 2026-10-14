part of 'location_screen.dart';

class _LocationBody extends StatelessWidget {
  const _LocationBody({
    required this.summary,
    required this.motorcycleTrips,
    required this.period,
    required this.workArrivalStats,
    required this.workAddress,
    required this.workHours,
    required this.weekendDays,
    required this.insights,
    required this.history,
    required this.profile,
    required this.trips,
    required this.placeNames,
    required this.onRenamePlace,
    this.onIdentify,
    this.identifying = false,
    this.fuel,
  });

  final LocationSummary summary;
  final List<TimelineActivity> motorcycleTrips;
  final AnalysisPeriod period;
  final WorkArrivalStats workArrivalStats;
  final String workAddress;
  final String workHours;
  final List<int> weekendDays;
  final MobilityFuelSummary? fuel;
  final LocationInsights insights;
  final List<MonthlyLocationRow> history;
  final LocationProfile profile;
  final List<TimelineTrip> trips;
  final Map<String, String> placeNames;
  final Future<void> Function(PlaceStat place) onRenamePlace;
  final VoidCallback? onIdentify;
  final bool identifying;

  @override
  Widget build(BuildContext context) {
    final decimal = NumberFormat.decimalPattern();
    final accent = AppSemanticColors.mobility(context);
    final other = AppSemanticColors.result(context);

    final motorcycleKm = summary.periodMotorcycleDistanceMeters / 1000;
    final totalKm = summary.periodTotalDistanceMeters / 1000;
    final otherKm = (totalKm - motorcycleKm).clamp(0.0, double.infinity);
    final leadsWithMotorcycle = motorcycleKm > 0;
    final headlineKm = leadsWithMotorcycle ? motorcycleKm : totalKm;

    final otherModes = summary.periodTransportationByType
        .where((mode) => mode.type != 'MOTORCYCLING')
        .toList();
    final weekendTrips = weekendDays.isEmpty
        ? const <TimelineActivity>[]
        : summary.periodMotorcycleActivitiesOnWeekendDays(weekendDays);
    final weekendKm =
        weekendTrips.fold(0.0, (sum, trip) => sum + trip.distanceMeters) / 1000;

    final days = buildDayBars([
      for (final a in summary.activities)
        if (leadsWithMotorcycle ? a.isMotorcycling : a.distanceMeters > 0)
          (date: a.startTime.toLocal(), value: a.distanceMeters / 1000),
    ], period.dataMonthStart);
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
              if (leadsWithMotorcycle && otherKm > 0)
                HeroStat('Other transport', '${otherKm.toStringAsFixed(1)} km'),
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
        categoryBox(
          CategoryPanel(
            title: leadsWithMotorcycle ? 'Rides by day' : 'Distance by day',
            child: DayBars(
              data: days,
              color: accent,
              format: (v) => '${v.toStringAsFixed(1)} km',
              emptyLabel: 'No trips recorded this month',
            ),
          ),
        ),
        if (insights.split.hasData)
          categoryBox(
            TimeSplitPanel(
              insights: insights,
              accent: accent,
              workColor: other,
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
        if (insights.places.isNotEmpty)
          categoryBox(
            PlacesPanel(
              insights: insights,
              names: placeNames,
              onRename: onRenamePlace,
              accent: accent,
              onIdentify: onIdentify,
              identifying: identifying,
            ),
          ),
        if (history.length >= 2)
          categoryBox(MonthlyTrendPanel(history: history, accent: accent)),
        if (trips.isNotEmpty)
          categoryBox(TripsAwayPanel(trips: trips, accent: accent)),
        if (workArrivalStats.hasWorkVisits && workArrivalStats.hasLateThreshold)
          categoryBox(
            _WorkArrivalsPanel(stats: workArrivalStats, accent: accent),
          ),
        if (otherModes.isNotEmpty)
          categoryBox(
            CategoryPanel(
              title: 'Other transport',
              child: BreakdownBars(
                color: other,
                items: [
                  for (final mode in otherModes)
                    (
                      label: _formatTransportType(mode.type),
                      value: mode.distanceMeters,
                      display:
                          '${(mode.distanceMeters / 1000).toStringAsFixed(1)} km · '
                          '${decimal.format(mode.tripCount)}',
                    ),
                ],
              ),
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
            title: 'Location data for analysis',
            accent: accent,
            icon: Icons.route_outlined,
          ),
        ),
      ],
    );
  }

  String _formatTransportType(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return 'Unknown';
    return normalized
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}
