part of 'location_panels.dart';

/// Motorcycle distance for each of the last twelve months.
class MonthlyTrendPanel extends StatelessWidget {
  const MonthlyTrendPanel({
    super.key,
    required this.history,
    required this.accent,
  });

  final List<MonthlyLocationRow> history;
  final Color accent;

  static const _months = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final rows = history.length > _months
        ? history.sublist(history.length - _months)
        : history;
    final useTotal = rows.every((r) => r.motorcycleKm == 0);
    double valueOf(MonthlyLocationRow r) =>
        useTotal ? r.totalKm : r.motorcycleKm;

    // Compare the last two *complete* months: the current one is partial.
    String? trailing;
    if (rows.length >= 3) {
      final last = valueOf(rows[rows.length - 2]);
      final before = valueOf(rows[rows.length - 3]);
      if (before > 0) {
        final change = (last - before) / before * 100;
        trailing =
            '${DateFormat.MMM().format(rows[rows.length - 2].month)} '
            '${change >= 0 ? '+' : '−'}${change.abs().round()}%';
      }
    }

    return CategoryPanel(
      title: useTotal ? 'Distance by month' : 'Rides by month',
      trailing: trailing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DayBars(
            data: [for (final r in rows) DayBarDatum(r.month, valueOf(r))],
            color: accent,
            format: (v) => '${v.round()} km',
            readoutDateFormat: 'MMMM yyyy',
            averageLabel: 'Average per month',
            unitNoun: 'months',
            axisLabel: (d) => DateFormat.MMM().format(d),
            axisLabelEvery: 2,
            emptyLabel: 'No history yet',
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The latest month is still in progress.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-day trips away from home that Google summarised.
class TripsAwayPanel extends StatelessWidget {
  const TripsAwayPanel({super.key, required this.trips, required this.accent});

  final List<TimelineTrip> trips;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final recent = (List<TimelineTrip>.of(
      trips,
    )..sort((a, b) => b.startTime.compareTo(a.startTime))).take(5).toList();
    final format = DateFormat('d MMM');

    return CategoryPanel(
      title: 'Trips away',
      trailing: 'all time',
      child: Column(
        children: [
          for (final trip in recent)
            CategoryRow(
              icon: Icons.luggage_outlined,
              accent: accent,
              title: '${trip.distanceFromOriginKm} km from home',
              subtitle:
                  '${format.format(trip.startTime.toLocal())} – '
                  '${format.format(trip.endTime.toLocal())}',
              trailing: '${trip.duration.inDays.clamp(1, 9999)} d',
            ),
        ],
      ),
    );
  }
}
