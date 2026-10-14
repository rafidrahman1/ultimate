import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/location/analysis/place_stats.dart';
import 'package:personal/features/location/data/location_insights_providers.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_profile.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/category/day_bars.dart';
import 'package:url_launcher/url_launcher.dart';

part 'location_help_and_actions.dart';
part 'location_places_panel.dart';
part 'location_trend_panels.dart';

String _clock(int minutesAfterMidnight) => DateFormat.jm().format(
  DateTime(2000, 1, 1, minutesAfterMidnight ~/ 60, minutesAfterMidnight % 60),
);

String _hours(double hours) => '${hours.toStringAsFixed(1)} h';

/// Home / work / elsewhere split of the tracked time, plus a per-day chart of
/// time spent away from home.
class TimeSplitPanel extends StatelessWidget {
  const TimeSplitPanel({
    super.key,
    required this.insights,
    required this.accent,
    required this.workColor,
  });

  final LocationInsights insights;
  final Color accent;
  final Color workColor;

  @override
  Widget build(BuildContext context) {
    final split = insights.split;
    final palette = context.palette;
    final theme = Theme.of(context);
    final elsewhereColor = palette.textMuted;

    int flex(double share) => (share * 1000).round();

    Widget legend(String label, double perDay, Color color) => Expanded(
      child: Semantics(
        label: '$label ${_hours(perDay)} per day',
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hours(perDay),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final away = [
      for (final day in insights.daily)
        DayBarDatum(day.date, day.away.inMinutes / 60),
    ];

    return CategoryPanel(
      title: 'Where your time went',
      trailing: 'per day',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (flex(split.homeShare) > 0)
                    Expanded(
                      flex: flex(split.homeShare),
                      child: ColoredBox(color: accent),
                    ),
                  if (flex(split.workShare) > 0)
                    Expanded(
                      flex: flex(split.workShare),
                      child: ColoredBox(color: workColor),
                    ),
                  if (flex(split.elsewhereShare) > 0)
                    Expanded(
                      flex: flex(split.elsewhereShare),
                      child: ColoredBox(color: elsewhereColor),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              legend('At home', split.homeHoursPerDay, accent),
              legend('At work', split.workHoursPerDay, workColor),
              legend('Elsewhere', split.elsewhereHoursPerDay, elsewhereColor),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Time away from home',
            style: theme.textTheme.labelMedium?.copyWith(
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          DayBars(
            data: away,
            color: workColor,
            format: _hours,
            emptyLabel: 'No visits recorded',
          ),
        ],
      ),
    );
  }
}

/// Door-to-door commute measured from your visits, next to the routine Google
/// has learned.
class CommutePanel extends StatelessWidget {
  const CommutePanel({
    super.key,
    required this.commute,
    required this.profile,
    required this.accent,
  });

  final CommuteStats commute;
  final LocationProfile profile;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CategoryPanel(
      title: 'Commute',
      trailing: 'door to door',
      child: Column(
        children: [
          if (commute.toWork.isNotEmpty)
            _CommuteRow(
              icon: Icons.work_outline_rounded,
              label: 'To work',
              samples: commute.toWork,
              routine: profile.tripsFor(CommuteDirection.homeToWork),
              accent: accent,
            ),
          if (commute.toWork.isNotEmpty && commute.toHome.isNotEmpty)
            const SizedBox(height: AppSpacing.md),
          if (commute.toHome.isNotEmpty)
            _CommuteRow(
              icon: Icons.home_outlined,
              label: 'Back home',
              samples: commute.toHome,
              routine: profile.tripsFor(CommuteDirection.workToHome),
              accent: accent,
            ),
        ],
      ),
    );
  }
}

class _CommuteRow extends StatelessWidget {
  const _CommuteRow({
    required this.icon,
    required this.label,
    required this.samples,
    required this.routine,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final List<CommuteSample> samples;
  final List<FrequentTrip> routine;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final average = CommuteStats.averageDuration(samples)!;
    final departure = CommuteStats.averageDepartureMinutes(samples)!;
    final longest = samples
        .map((s) => s.duration)
        .reduce((a, b) => a > b ? a : b);

    final typical = routine.isEmpty
        ? null
        : routine.fold<int>(0, (sum, t) => sum + t.durationMinutes) ~/
              routine.length;
    final delta = typical == null ? null : average.inMinutes - typical;

    return Row(
      children: [
        Icon(icon, color: accent),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label · usually leaves ${_clock(departure)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${samples.length} ${samples.length == 1 ? 'day' : 'days'} · '
                'longest ${formatTravelDuration(longest)}'
                '${typical == null ? '' : ' · Google expects $typical m'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatTravelDuration(average),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            if (delta != null && delta.abs() >= 2)
              Text(
                '${delta > 0 ? '+' : '−'}${delta.abs()} m',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: delta > 0 ? palette.warning : palette.textMuted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
