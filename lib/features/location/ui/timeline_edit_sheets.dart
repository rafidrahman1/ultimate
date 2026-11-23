part of 'timeline_day_screen.dart';

// --- Visits -------------------------------------------------------------------

Future<void> showVisitEditSheet(
  BuildContext context,
  WidgetRef ref,
  TimelinePlaceVisit visit,
) {
  final names = ref.read(placeNamesProvider);
  final placeId = visit.placeId;
  final time = DateFormat('h:mm a');
  final edits = ref.read(locationEditsProvider.notifier);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      void close() => Navigator.pop(sheet);
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHeader(
                title: visitDisplayName(visit, names),
                subtitle:
                    '${time.format(visit.startTime.toLocal())} – '
                    '${time.format(visit.endTime.toLocal())}',
              ),
              if (placeId != null)
                ListTile(
                  leading: const Icon(Icons.drive_file_rename_outline),
                  title: const Text('Rename this place'),
                  subtitle: const Text('Every visit here gets the new name'),
                  onTap: () async {
                    close();
                    final name = await _askText(
                      context,
                      title: 'Name this place',
                      initial: names[placeId] ?? '',
                    );
                    if (name != null) {
                      ref.read(placeNamesProvider.notifier).renameIds([
                        placeId,
                      ], name);
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.wrong_location_outlined),
                title: const Text('I was somewhere else'),
                subtitle: const Text('Pick the right place or add a new one'),
                onTap: () async {
                  close();
                  await _pickOtherPlace(context, ref, visit);
                },
              ),
              if (placeId != null) ...[
                if (!visit.isAtHome)
                  ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: const Text('This place is Home'),
                    onTap: () {
                      close();
                      edits.setPlaceKind(placeId, PlaceKindOverride.home);
                    },
                  ),
                if (!visit.isAtWork)
                  ListTile(
                    leading: const Icon(Icons.work_outline_rounded),
                    title: const Text('This place is Work'),
                    onTap: () {
                      close();
                      edits.setPlaceKind(placeId, PlaceKindOverride.work);
                    },
                  ),
                if (visit.isAtHome || visit.isAtWork)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(
                      'This isn\'t ${visit.isAtHome ? 'Home' : 'Work'}',
                    ),
                    onTap: () {
                      close();
                      edits.setPlaceKind(placeId, PlaceKindOverride.other);
                    },
                  ),
              ],
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Change arrival / departure time'),
                onTap: () async {
                  close();
                  await _editTimes(
                    context,
                    ref,
                    isVisit: true,
                    sourceStart: visit.sourceStart,
                    sourceEnd: visit.sourceEnd,
                    start: visit.startTime,
                    end: visit.endTime,
                    previous: visit.editIds,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.not_listed_location_outlined),
                title: const Text('I didn\'t stop here'),
                subtitle: const Text(
                  'Removes it and joins the trips either side',
                ),
                onTap: () {
                  close();
                  _removeWithUndo(
                    context,
                    ref,
                    isVisit: true,
                    sourceStart: visit.sourceStart,
                    sourceEnd: visit.sourceEnd,
                    message: 'Stop removed',
                  );
                },
              ),
              if (visit.isEdited) _UndoTile(ids: visit.editIds, onDone: close),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _pickOtherPlace(
  BuildContext context,
  WidgetRef ref,
  TimelinePlaceVisit visit,
) async {
  final catalog = ref.read(placeCatalogProvider);
  final names = ref.read(placeNamesProvider);
  final here = visit.point;
  final options = [
    for (final p in catalog)
      if (p.id != visit.placeId) p,
  ];
  if (here != null) {
    options.sort(
      (a, b) => a.point.distanceTo(here).compareTo(b.point.distanceTo(here)),
    );
  } else {
    options.sort((a, b) => b.visits.compareTo(a.visits));
  }

  String nameOf(PlaceOption option) {
    final custom = names[option.id];
    if (custom != null && custom.isNotEmpty) return custom;
    return switch (option.semanticType) {
      'TYPE_HOME' || 'TYPE_INFERRED_HOME' => 'Home',
      'TYPE_WORK' || 'TYPE_INFERRED_WORK' => 'Work',
      _ => 'Unnamed place',
    };
  }

  final picked = await showModalBottomSheet<_PlaceChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) =>
        _PlacePicker(options: options, here: here, nameOf: nameOf),
  );
  if (picked == null || !context.mounted) return;

  final String placeId;
  final GeoPoint? point;
  String? semantic;
  String? placeName;
  if (picked.option != null) {
    placeId = picked.option!.id;
    point = picked.option!.point;
    semantic = picked.option!.semanticType;
    placeName = nameOf(picked.option!);
  } else {
    if (here == null) return;
    final name = await _askText(context, title: 'Name the new place');
    if (name == null) return;
    placeId = 'usr:${clock.now().millisecondsSinceEpoch.toRadixString(36)}';
    point = here;
    placeName = name.trim().isEmpty ? null : name.trim();
    if (placeName != null) {
      ref.read(placeNamesProvider.notifier).renameIds([placeId], placeName);
    }
  }

  final edits = ref.read(locationEditsProvider.notifier);
  _dropPrevious(ref, visit.editIds, LocationEditKind.place);
  edits.add(
    LocationEdit(
      id: LocationEditsController.newId(),
      kind: LocationEditKind.place,
      isVisit: true,
      matchStart: visit.sourceStart,
      matchEnd: visit.sourceEnd,
      placeId: placeId,
      placeName: placeName == 'Unnamed place' ? null : placeName,
      semanticType: semantic,
      point: point,
    ),
  );
}

class _PlaceChoice {
  const _PlaceChoice(this.option);

  /// Null for "a new place here".
  final PlaceOption? option;
}

class _PlacePicker extends StatefulWidget {
  const _PlacePicker({
    required this.options,
    required this.here,
    required this.nameOf,
  });

  final List<PlaceOption> options;
  final GeoPoint? here;
  final String Function(PlaceOption) nameOf;

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final query = _query.toLowerCase();
    final shown = [
      for (final o in widget.options)
        if (query.isEmpty || widget.nameOf(o).toLowerCase().contains(query)) o,
    ].take(40).toList();

    String distance(PlaceOption o) {
      final here = widget.here;
      if (here == null) return '${o.visits} visits';
      final m = o.point.distanceTo(here);
      final away = m < 1000
          ? '${m.round()} m away'
          : '${(m / 1000).toStringAsFixed(1)} km away';
      return '$away · ${o.visits} visits';
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search your places',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (widget.here != null)
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('A new place here'),
              subtitle: const Text('Somewhere not in the list'),
              onTap: () => Navigator.pop(context, const _PlaceChoice(null)),
            ),
          Divider(height: 1, color: palette.border),
          Expanded(
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) => ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(widget.nameOf(shown[i])),
                subtitle: Text(distance(shown[i])),
                onTap: () => Navigator.pop(context, _PlaceChoice(shown[i])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Trips --------------------------------------------------------------------

Future<void> showTripEditSheet(
  BuildContext context,
  WidgetRef ref,
  TimelineActivity trip,
) {
  final time = DateFormat('h:mm a');
  final hours = trip.duration.inSeconds / 3600;
  final avgKmh = hours <= 0 ? null : trip.distanceMeters / 1000 / hours;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      void close() => Navigator.pop(sheet);
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHeader(
                title:
                    '${TravelModes.label(trip.type)} · '
                    '${(trip.distanceMeters / 1000).toStringAsFixed(1)} km',
                subtitle:
                    '${time.format(trip.startTime.toLocal())} – '
                    '${time.format(trip.endTime.toLocal())}'
                    '${avgKmh == null ? '' : ' · avg ${avgKmh.round()} km/h'}',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  'How did you travel?',
                  style: Theme.of(sheet).textTheme.labelLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final mode in TravelModes.all)
                      ChoiceChip(
                        avatar: Icon(travelModeIcon(mode), size: 18),
                        label: Text(TravelModes.label(mode)),
                        selected: trip.type.toUpperCase() == mode,
                        onSelected: (_) {
                          close();
                          if (trip.type.toUpperCase() == mode) return;
                          _dropPrevious(
                            ref,
                            trip.editIds,
                            LocationEditKind.mode,
                          );
                          ref
                              .read(locationEditsProvider.notifier)
                              .add(
                                LocationEdit(
                                  id: LocationEditsController.newId(),
                                  kind: LocationEditKind.mode,
                                  isVisit: false,
                                  matchStart: trip.sourceStart,
                                  matchEnd: trip.sourceEnd,
                                  type: mode,
                                  avgKmh: avgKmh,
                                ),
                              );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Change start / end time'),
                onTap: () async {
                  close();
                  await _editTimes(
                    context,
                    ref,
                    isVisit: false,
                    sourceStart: trip.sourceStart,
                    sourceEnd: trip.sourceEnd,
                    start: trip.startTime,
                    end: trip.endTime,
                    previous: trip.editIds,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('This trip didn\'t happen'),
                onTap: () {
                  close();
                  _removeWithUndo(
                    context,
                    ref,
                    isVisit: false,
                    sourceStart: trip.sourceStart,
                    sourceEnd: trip.sourceEnd,
                    message: 'Trip removed',
                  );
                },
              ),
              if (trip.isEdited) _UndoTile(ids: trip.editIds, onDone: close),
            ],
          ),
        ),
      );
    },
  );
}

// --- Shared -------------------------------------------------------------------

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _UndoTile extends ConsumerWidget {
  const _UndoTile({required this.ids, required this.onDone});

  final List<String> ids;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.restore_rounded),
      title: const Text('Undo my changes'),
      subtitle: const Text('Back to what was detected'),
      onTap: () {
        onDone();
        ref.read(locationEditsProvider.notifier).removeIds(ids);
      },
    );
  }
}

/// Drops earlier edits of [kind] on this entry so the newest one is the only
/// one kept.
void _dropPrevious(
  WidgetRef ref,
  List<String> entryEditIds,
  LocationEditKind kind,
) {
  final ids = entryEditIds.toSet();
  final stale = [
    for (final e in ref.read(locationEditsProvider).edits)
      if (ids.contains(e.id) && e.kind == kind) e.id,
  ];
  if (stale.isNotEmpty) {
    ref.read(locationEditsProvider.notifier).removeIds(stale);
  }
}

void _removeWithUndo(
  BuildContext context,
  WidgetRef ref, {
  required bool isVisit,
  required DateTime sourceStart,
  required DateTime sourceEnd,
  required String message,
}) {
  final edits = ref.read(locationEditsProvider.notifier);
  final id = edits.add(
    LocationEdit(
      id: LocationEditsController.newId(),
      kind: LocationEditKind.remove,
      isVisit: isVisit,
      matchStart: sourceStart,
      matchEnd: sourceEnd,
    ),
  );
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => edits.removeIds([id]),
      ),
    ),
  );
}

Future<void> _editTimes(
  BuildContext context,
  WidgetRef ref, {
  required bool isVisit,
  required DateTime sourceStart,
  required DateTime sourceEnd,
  required DateTime start,
  required DateTime end,
  required List<String> previous,
}) async {
  final localStart = start.toLocal();
  final localEnd = end.toLocal();
  final newStart = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(localStart),
    helpText: isVisit ? 'ARRIVED AT' : 'STARTED AT',
  );
  if (newStart == null || !context.mounted) return;
  final newEnd = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(localEnd),
    helpText: isVisit ? 'LEFT AT' : 'ENDED AT',
  );
  if (newEnd == null || !context.mounted) return;

  DateTime on(DateTime day, TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);
  final from = on(localStart, newStart);
  final to = on(localEnd, newEnd);
  if (!to.isAfter(from)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The end has to be after the start.')),
    );
    return;
  }
  _dropPrevious(ref, previous, LocationEditKind.times);
  ref
      .read(locationEditsProvider.notifier)
      .add(
        LocationEdit(
          id: LocationEditsController.newId(),
          kind: LocationEditKind.times,
          isVisit: isVisit,
          matchStart: sourceStart,
          matchEnd: sourceEnd,
          newStart: from,
          newEnd: to,
        ),
      );
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPrompt(title: title, initial: initial),
  );
}

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'e.g. Gym, Mum\'s place'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
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
