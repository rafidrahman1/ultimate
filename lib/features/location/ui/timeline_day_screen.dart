import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/location/data/location_edits.dart';
import 'package:personal/features/location/data/location_insights_providers.dart';
import 'package:personal/features/location/data/location_service.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_profile.dart';
import 'package:personal/features/location/recording/recording_providers.dart';
import 'package:personal/features/location/recording/travel_mode_classifier.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';

part 'timeline_edit_sheets.dart';

/// One day of visits and trips, each tappable to correct it.
class TimelineDayScreen extends ConsumerStatefulWidget {
  const TimelineDayScreen({super.key});

  @override
  ConsumerState<TimelineDayScreen> createState() => _TimelineDayScreenState();
}

class _TimelineDayScreenState extends ConsumerState<TimelineDayScreen> {
  late DateTime _day = _today();

  static DateTime _today() {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(ref.read(recordedSegmentsProvider.notifier).refresh()),
    );
  }

  void _shift(int days) {
    final next = DateTime(_day.year, _day.month, _day.day + days);
    if (next.isAfter(_today())) return;
    setState(() => _day = next);
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2010),
      lastDate: _today(),
    );
    if (picked != null) setState(() => _day = picked);
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(locationSummaryProvider);
    final names = ref.watch(placeNamesProvider);
    final entries = _entriesOn(summary, _day);
    final editIds = {for (final e in entries) ...e.editIds};
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: [
          if (editIds.isNotEmpty)
            IconButton(
              tooltip: 'Undo all changes on this day',
              icon: const Icon(Icons.restore_rounded),
              onPressed: () => _confirmUndoDay(editIds),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(recordedSegmentsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.sm,
            AppSpacing.screen,
            AppSpacing.xl,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous day',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _shift(-1),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _pickDay,
                    child: Text(
                      '${dayLabel(_day)} · ${DateFormat('d MMM y').format(_day)}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next day',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _day.isBefore(_today()) ? () => _shift(1) : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tap anything that looks wrong to fix it. Your fixes also teach '
              'the recorder which travel mode you usually use.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Text(
                  'Nothing recorded on this day.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, indent: 16, color: palette.border),
                      _EntryRow(
                        entry: entries[i],
                        names: names,
                        onTap: () => _openEntry(entries[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openEntry(_Entry entry) {
    final visit = entry.visit;
    if (visit != null) {
      unawaited(showVisitEditSheet(context, ref, visit));
    } else {
      unawaited(showTripEditSheet(context, ref, entry.trip!));
    }
  }

  Future<void> _confirmUndoDay(Set<String> ids) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Undo changes?'),
        content: Text(
          'Put back what was detected for ${dayLabel(_day).toLowerCase()}, '
          'undoing ${ids.length} ${ids.length == 1 ? 'change' : 'changes'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(locationEditsProvider.notifier).removeIds(ids);
  }
}

/// A visit or a trip.
class _Entry {
  const _Entry.visit(TimelinePlaceVisit this.visit) : trip = null;
  const _Entry.trip(TimelineActivity this.trip) : visit = null;

  final TimelinePlaceVisit? visit;
  final TimelineActivity? trip;

  DateTime get start => (visit?.startTime ?? trip!.startTime).toLocal();
  DateTime get end => (visit?.endTime ?? trip!.endTime).toLocal();
  List<String> get editIds => visit?.editIds ?? trip!.editIds;
  TimelineSource get source => visit?.source ?? trip!.source;
}

List<_Entry> _entriesOn(LocationSummary summary, DateTime day) {
  final next = DateTime(day.year, day.month, day.day + 1);
  bool overlaps(DateTime start, DateTime end) =>
      start.toLocal().isBefore(next) && end.toLocal().isAfter(day);
  return [
    for (final v in summary.placeVisits)
      if (!v.isNested && overlaps(v.startTime, v.endTime)) _Entry.visit(v),
    for (final a in summary.activities)
      if (overlaps(a.startTime, a.endTime)) _Entry.trip(a),
  ]..sort((a, b) => a.start.compareTo(b.start));
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.names,
    required this.onTap,
  });

  final _Entry entry;
  final Map<String, String> names;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a');
    final range =
        '${time.format(entry.start)} – ${time.format(entry.end)}'
        ' · ${formatTravelDuration(entry.end.difference(entry.start))}';
    final tags = [
      if (entry.source == TimelineSource.device) 'Recorded',
      if (entry.editIds.isNotEmpty) 'Edited',
    ].join(' · ');
    final visit = entry.visit;
    if (visit != null) {
      return CategoryRow(
        icon: _visitIcon(visit),
        accent: AppSemanticColors.mobility(context),
        title: visitDisplayName(visit, names),
        subtitle: range,
        detail: tags.isEmpty ? null : tags,
        onTap: onTap,
      );
    }
    final trip = entry.trip!;
    return CategoryRow(
      icon: travelModeIcon(trip.type),
      accent: AppSemanticColors.mobility(context),
      muted: true,
      title:
          '${TravelModes.label(trip.type)} · '
          '${(trip.distanceMeters / 1000).toStringAsFixed(1)} km',
      subtitle: range,
      detail: tags.isEmpty ? null : tags,
      onTap: onTap,
    );
  }
}

IconData _visitIcon(TimelinePlaceVisit visit) {
  if (visit.isAtHome) return Icons.home_outlined;
  if (visit.isAtWork) return Icons.work_outline_rounded;
  return Icons.place_outlined;
}

/// The place's name: yours, else Home / Work, else what the source called it.
String visitDisplayName(TimelinePlaceVisit visit, Map<String, String> names) {
  final custom = names[visit.placeId];
  if (custom != null && custom.isNotEmpty) return custom;
  if (visit.isAtHome) return 'Home';
  if (visit.isAtWork) return 'Work';
  return visit.name;
}

IconData travelModeIcon(String type) => switch (type.toUpperCase()) {
  TravelModes.walking => Icons.directions_walk_rounded,
  TravelModes.running => Icons.directions_run_rounded,
  TravelModes.cycling => Icons.directions_bike_rounded,
  TravelModes.motorcycling => Icons.two_wheeler_rounded,
  TravelModes.car => Icons.directions_car_rounded,
  TravelModes.taxi => Icons.local_taxi_rounded,
  TravelModes.bus => Icons.directions_bus_rounded,
  TravelModes.train => Icons.train_rounded,
  TravelModes.subway => Icons.subway_rounded,
  TravelModes.boat => Icons.directions_boat_rounded,
  TravelModes.flying => Icons.flight_rounded,
  _ => Icons.route_rounded,
};
