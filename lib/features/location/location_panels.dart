import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/location/location_insights_providers.dart';
import 'package:personal/features/location/place_stats.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/timeline_profile.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/category/day_bars.dart';

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

IconData _kindIcon(PlaceKind kind) => switch (kind) {
  PlaceKind.home => Icons.home_outlined,
  PlaceKind.work => Icons.work_outline_rounded,
  PlaceKind.other => Icons.place_outlined,
};

/// Top places by time spent, with counts for new places and the furthest
/// point from home. Tap a place to name it; the export carries no names.
class PlacesPanel extends StatelessWidget {
  const PlacesPanel({
    super.key,
    required this.insights,
    required this.names,
    required this.onRename,
    required this.accent,
  });

  final LocationInsights insights;
  final Map<String, String> names;
  final Future<void> Function(PlaceStat place) onRename;
  final Color accent;

  static const _shown = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final places = insights.places;
    final top = places.take(_shown).toList();

    Widget stat(String value, String label) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
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
    );

    final furthest = insights.furthestFromHomeKm;
    return CategoryPanel(
      title: 'Places',
      trailing: '${insights.uniquePlaces} visited',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              stat('${insights.uniquePlaces}', 'places'),
              if (insights.newPlaces != null)
                stat('${insights.newPlaces}', 'new this period'),
              if (furthest != null && furthest >= 1)
                stat('${furthest.round()} km', 'furthest from home'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final place in top)
            CategoryRow(
              icon: _kindIcon(place.kind),
              accent: accent,
              title: placeDisplayName(place, names),
              subtitle:
                  '${place.visits} ${place.visits == 1 ? 'visit' : 'visits'}'
                  ' · avg stay ${formatTravelDuration(place.averageStay)}',
              trailing: formatTravelDuration(place.totalDwell),
              onTap: () => onRename(place),
            ),
          if (places.length > _shown)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (sheet) => _AllPlacesSheet(
                    places: places,
                    names: names,
                    accent: accent,
                    onRename: onRename,
                  ),
                ),
                child: Text('All ${places.length} places'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Tap a place to name it. Names stay on this device.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllPlacesSheet extends StatelessWidget {
  const _AllPlacesSheet({
    required this.places,
    required this.names,
    required this.accent,
    required this.onRename,
  });

  final List<PlaceStat> places;
  final Map<String, String> names;
  final Color accent;
  final Future<void> Function(PlaceStat place) onRename;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.xxl,
        ),
        itemCount: places.length,
        itemBuilder: (context, index) {
          final place = places[index];
          return CategoryRow(
            icon: _kindIcon(place.kind),
            accent: accent,
            title: placeDisplayName(place, names),
            subtitle:
                '${place.visits} ${place.visits == 1 ? 'visit' : 'visits'}'
                ' · last ${DateFormat('d MMM').format(place.lastSeen)}',
            trailing: formatTravelDuration(place.totalDwell),
            onTap: () => onRename(place),
          );
        },
      ),
    );
  }
}

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

/// Shown when no Timeline file is found: where the export comes from.
class TimelineExportHelp extends StatelessWidget {
  const TimelineExportHelp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    const steps = [
      'Open Google Maps, tap your profile picture, then Settings.',
      'Choose Your Timeline (or Location and Timeline).',
      'Tap Export Timeline data and save it into your Personal data folder.',
      'Come back here and tap Reload (or pull down).',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to export your Timeline',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              '${i + 1}. ${steps[i]}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Name a place. Returns the entered text ('' to clear), or null if cancelled.
Future<String?> showRenamePlaceDialog(
  BuildContext context, {
  required String current,
  required String fallback,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenamePlaceDialog(current: current, fallback: fallback),
  );
}

class _RenamePlaceDialog extends StatefulWidget {
  const _RenamePlaceDialog({required this.current, required this.fallback});

  final String current;
  final String fallback;

  @override
  State<_RenamePlaceDialog> createState() => _RenamePlaceDialogState();
}

class _RenamePlaceDialogState extends State<_RenamePlaceDialog> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this place'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 40,
        decoration: InputDecoration(
          hintText: widget.fallback,
          helperText: 'Included in analysis once named.',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        if (widget.current.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Clear'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
