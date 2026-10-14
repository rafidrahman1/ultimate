part of 'location_panels.dart';

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
    this.onIdentify,
    this.identifying = false,
  });

  final LocationInsights insights;
  final Map<String, String> names;
  final Future<void> Function(PlaceStat place) onRename;
  final Color accent;

  /// Null hides the button (AI not set up, or nothing left to name).
  final VoidCallback? onIdentify;
  final bool identifying;

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
          if (onIdentify != null || identifying)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: identifying ? null : onIdentify,
                  icon: identifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    identifying ? 'Identifying…' : 'Identify places with AI',
                  ),
                ),
              ),
            ),
          for (final place in top)
            CategoryRow(
              icon: _kindIcon(place.kind),
              accent: accent,
              title: placeDisplayName(place, names),
              subtitle:
                  '${place.visits} ${place.visits == 1 ? 'visit' : 'visits'}'
                  ' · avg stay ${formatTravelDuration(place.averageStay)}',
              trailing: formatTravelDuration(place.totalDwell),
              onTap: () => openPlaceOnMap(
                context,
                place,
                placeDisplayName(place, names),
              ),
              onLongPress: () => onRename(place),
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
              'Tap a place to open it on the map; press and hold to rename.',
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

class _AllPlacesSheet extends ConsumerWidget {
  const _AllPlacesSheet({
    required this.places,
    required this.accent,
    required this.onRename,
  });

  final List<PlaceStat> places;
  final Color accent;
  final Future<void> Function(PlaceStat place) onRename;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(placeNamesProvider);
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
            onTap: () =>
                openPlaceOnMap(context, place, placeDisplayName(place, names)),
            onLongPress: () => onRename(place),
          );
        },
      ),
    );
  }
}
