part of 'location_screen.dart';

/// On-time vs late split for workdays, with the late days listed.
class _WorkArrivalsPanel extends StatelessWidget {
  const _WorkArrivalsPanel({required this.stats, required this.accent});

  final WorkArrivalStats stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final total = stats.totalWorkDays;
    final late = stats.lateArrivalCount;
    final onTime = (total - late).clamp(0, total);
    final dateFormat = DateFormat('EEE d MMM · h:mm a');
    final lateDays = stats.lateArrivals.take(5).toList();

    return CategoryPanel(
      title: 'Work arrivals',
      trailing: 'after ${stats.thresholdLabel}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$onTime',
                style: context.statDisplay.copyWith(color: accent),
              ),
              const SizedBox(width: 6),
              Text(
                'of $total workdays on time',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (onTime > 0)
                      Expanded(
                        flex: onTime,
                        child: ColoredBox(color: accent),
                      ),
                    if (late > 0)
                      Expanded(
                        flex: late,
                        child: ColoredBox(color: palette.warning),
                      ),
                  ],
                ),
              ),
            ),
          if (lateDays.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '$late late ${late == 1 ? 'arrival' : 'arrivals'}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final day in lateDays)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  dateFormat.format(day.arrivalTime),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            if (stats.lateArrivals.length > lateDays.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${stats.lateArrivals.length - lateDays.length} more',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip});

  final TimelineActivity trip;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a');
    final start = trip.startTime.toLocal();
    final end = trip.endTime.toLocal();
    return CategoryRow(
      icon: Icons.two_wheeler_outlined,
      accent: AppSemanticColors.mobility(context),
      title: '${(trip.distanceMeters / 1000).toStringAsFixed(1)} km',
      subtitle: '${time.format(start)} → ${time.format(end)}',
      trailing: formatTravelDuration(end.difference(start)),
    );
  }
}
