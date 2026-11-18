import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/location/analysis/place_stats.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_profile.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';

part 'location_help_and_actions.dart';

String _clock(int minutesAfterMidnight) => DateFormat.jm().format(
  DateTime(2000, 1, 1, minutesAfterMidnight ~/ 60, minutesAfterMidnight % 60),
);

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
                fontWeight: FontWeight.w700,
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
