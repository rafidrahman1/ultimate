part of 'location_screen.dart';

/// On-time vs late arrivals for the month, laid out as a calendar.
class _WorkArrivalsPanel extends StatelessWidget {
  const _WorkArrivalsPanel({
    required this.stats,
    required this.month,
    required this.leaveDays,
    required this.accent,
  });

  final WorkArrivalStats stats;
  final DateTime month;
  final Map<DateTime, LeaveType> leaveDays;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final status = StatusColors.of(context);
    final total = stats.totalWorkDays;
    final late = stats.lateArrivalCount;
    final onTime = (total - late).clamp(0, total);
    final leaveColors = _leaveColors(context);
    final arrivalDays = {for (final d in stats.workDays) d.date};
    final leaveCounts = <LeaveType, int>{};
    for (final entry in leaveDays.entries) {
      final day = entry.key;
      if (day.year != month.year || day.month != month.month) continue;
      if (arrivalDays.contains(day)) continue;
      leaveCounts.update(entry.value, (n) => n + 1, ifAbsent: () => 1);
    }

    Widget legend(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: palette.textMuted),
        ),
      ],
    );

    return CategoryPanel(
      title: 'Work arrivals',
      trailing: 'start ${stats.thresholdLabel}',
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
              Expanded(
                child: Text(
                  'of $total workdays on time',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ArrivalCalendar(
            month: month,
            days: stats.workDays,
            leaveDays: leaveDays,
            onTimeColor: status.good,
            lateColor: status.critical,
            leaveColors: leaveColors,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              legend(status.good, 'On time · $onTime'),
              legend(status.critical, 'Late · $late'),
              for (final type in LeaveType.values)
                if ((leaveCounts[type] ?? 0) > 0)
                  legend(
                    leaveColors[type]!,
                    '${type.label} · ${leaveCounts[type]}',
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Month grid with each workday tinted on-time or late and its arrival time.
class _ArrivalCalendar extends StatelessWidget {
  const _ArrivalCalendar({
    required this.month,
    required this.days,
    required this.leaveDays,
    required this.onTimeColor,
    required this.lateColor,
    required this.leaveColors,
  });

  final DateTime month;
  final List<WorkDayArrival> days;
  final Map<DateTime, LeaveType> leaveDays;
  final Color onTimeColor;
  final Color lateColor;
  final Map<LeaveType, Color> leaveColors;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = DateTime(month.year, month.month, 1).weekday - 1;
    final byDay = {
      for (final d in days)
        if (d.date.year == month.year && d.date.month == month.month)
          d.date.day: d,
    };
    final time = DateFormat('h:mm');
    final spoken = DateFormat('d MMMM');

    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.8,
          ),
          itemCount: leading + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final day = index - leading + 1;
            final arrival = byDay[day];
            final date = DateTime(month.year, month.month, day);
            // A day you actually went in shows the arrival, even if leave
            // was booked.
            final leave = arrival == null ? leaveDays[date] : null;
            final color = arrival != null
                ? (arrival.isLate ? lateColor : onTimeColor)
                : leave != null
                ? leaveColors[leave]
                : null;
            final label = leave != null
                ? '${spoken.format(date)}, ${leave.label.toLowerCase()}'
                : arrival == null
                ? '${spoken.format(date)}, no work arrival'
                : '${spoken.format(date)}, arrived '
                      '${DateFormat.jm().format(arrival.arrivalTime)}, '
                      '${arrival.isLate ? '${arrival.delayMinutes} minutes late' : 'on time'}';

            return Semantics(
              label: label,
              excludeSemantics: true,
              child: Container(
                decoration: BoxDecoration(
                  color: color?.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  border: Border.all(
                    color: color ?? palette.border,
                    width: color == null ? 1 : 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: color == null
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: color == null
                            ? palette.textMuted
                            : palette.textPrimary,
                      ),
                    ),
                    if (arrival != null || leave != null)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          arrival != null
                              ? time.format(arrival.arrivalTime)
                              : leave!.shortLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

Map<LeaveType, Color> _leaveColors(BuildContext context) => {
  LeaveType.sick: StatusColors.of(context).warning,
  LeaveType.casual: AppSemanticColors.calendar(context),
};

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
