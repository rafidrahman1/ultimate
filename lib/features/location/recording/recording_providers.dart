import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/json_file_cache.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/location/data/location_edits.dart';
import 'package:personal/features/location/data/location_insights_providers.dart';
import 'package:personal/features/location/data/location_service.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_profile.dart';
import 'package:personal/features/location/recording/location_recorder.dart';
import 'package:personal/features/location/recording/raw_location_log.dart';
import 'package:personal/features/location/recording/recorded_timeline_builder.dart';
import 'package:personal/features/location/recording/timeline_segmenter.dart';
import 'package:personal/features/location/recording/travel_mode_classifier.dart';

const _segmentsCacheKey = 'location_recorded_v1';
const _editsKey = 'location_edits_v1';

// --- Recorded segments ------------------------------------------------------

/// Visits and trips worked out from the phone's raw log, cached so only new
/// data is processed on each refresh.
final recordedSegmentsProvider =
    AsyncNotifierProvider<RecordedSegmentsController, List<RecordedSegment>>(
      RecordedSegmentsController.new,
    );

class RecordedSegmentsController extends AsyncNotifier<List<RecordedSegment>> {
  /// Raw data from here on is re-processed next time: the last visit may still
  /// be going on.
  int _resumeFromMs = 0;
  Future<void>? _running;

  @override
  Future<List<RecordedSegment>> build() async {
    final cached = await _loadCache();
    unawaited(Future.microtask(refresh));
    return cached;
  }

  /// Reads new raw data and re-segments from the last visit on.
  Future<void> refresh() => _running ??= _refresh().whenComplete(() {
    _running = null;
  });

  Future<void> _refresh() async {
    final status = await ref.read(locationRecorderProvider.future);
    final dir = status.logDir;
    if (dir == null) return;
    final kept = state.value ?? const <RecordedSegment>[];
    final resume = _resumeFromMs;
    try {
      final result = await _processInBackground(dir, kept, resume);
      _resumeFromMs = result.resumeFromMs;
      state = AsyncData(result.segments);
      await JsonFileCache.instance.write(_segmentsCacheKey, {
        'resume': result.resumeFromMs,
        'segments': [for (final s in result.segments) s.toJson()],
      });
    } catch (error, stack) {
      AppLog.warn('Processing the recorded timeline failed: $error\n$stack');
    }
  }

  Future<List<RecordedSegment>> _loadCache() async {
    final json = await JsonFileCache.instance.read(_segmentsCacheKey);
    if (json == null) return const [];
    _resumeFromMs = (json['resume'] as num?)?.toInt() ?? 0;
    return [
      for (final raw in (json['segments'] as List?) ?? const [])
        if (raw is Map) ?RecordedSegment.fromJson(raw.cast<String, dynamic>()),
    ];
  }
}

typedef _Processed = ({List<RecordedSegment> segments, int resumeFromMs});

/// Top-level so the isolate closure captures only its arguments.
Future<_Processed> _processInBackground(
  String dir,
  List<RecordedSegment> kept,
  int resumeFromMs,
) => Isolate.run(() => _processLog(dir, kept, resumeFromMs));

_Processed _processLog(
  String dir,
  List<RecordedSegment> kept,
  int resumeFromMs,
) {
  // An hour of activity history before the cut, so a vehicle ride that began
  // just before it is still known to be one.
  final log = readRawLogDirectory(dir, fromMs: resumeFromMs - 3600000);
  final fresh = segmentTimeline(
    RawLog(
      fixes: [
        for (final f in log.fixes)
          if (f.timeMs >= resumeFromMs) f,
      ],
      activities: log.activities,
    ),
  );
  final combined = [
    for (final s in kept)
      if (s.startMs < resumeFromMs) s,
    ...fresh,
  ];
  final lastVisit = combined.lastWhere(
    (s) => s.isVisit,
    orElse: () =>
        const RecordedSegment(kind: RecordedKind.move, startMs: -1, endMs: -1),
  );
  return (
    segments: combined,
    resumeFromMs: lastVisit.startMs < 0 ? resumeFromMs : lastVisit.startMs,
  );
}

// --- Your corrections -------------------------------------------------------

final locationEditsProvider =
    NotifierProvider<LocationEditsController, LocationEdits>(
      LocationEditsController.new,
    );

class LocationEditsController extends Notifier<LocationEdits> {
  bool _changed = false;

  @override
  LocationEdits build() {
    unawaited(_hydrate());
    return LocationEdits.empty;
  }

  /// Adds [edit] and returns its id (for undo).
  String add(LocationEdit edit) {
    _set(
      LocationEdits(
        edits: [...state.edits, edit],
        placeKinds: state.placeKinds,
      ),
    );
    return edit.id;
  }

  /// Undoes the edits with these ids.
  void removeIds(Iterable<String> ids) {
    final drop = ids.toSet();
    _set(
      LocationEdits(
        edits: [
          for (final e in state.edits)
            if (!drop.contains(e.id)) e,
        ],
        placeKinds: state.placeKinds,
      ),
    );
  }

  /// Marks a place as home / work / neither; null clears your mark.
  void setPlaceKind(String placeId, PlaceKindOverride? kind) {
    final kinds = Map<String, PlaceKindOverride>.of(state.placeKinds);
    if (kind == null) {
      kinds.remove(placeId);
    } else {
      // Only one home and one work.
      if (kind != PlaceKindOverride.other) {
        kinds.removeWhere((_, k) => k == kind);
      }
      kinds[placeId] = kind;
    }
    _set(LocationEdits(edits: state.edits, placeKinds: kinds));
  }

  static String newId() =>
      'e${clock.now().microsecondsSinceEpoch.toRadixString(36)}';

  void _set(LocationEdits next) {
    _changed = true;
    state = next;
    unawaited(_persist());
  }

  Future<void> _hydrate() async {
    final raw = (await safePrefs())?.getString(_editsKey);
    if (raw == null || raw.isEmpty || _changed) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        state = LocationEdits.fromJson(decoded.cast<String, dynamic>());
      }
    } on FormatException {
      // Corrupt: start over rather than crash.
    }
  }

  Future<void> _persist() async {
    await (await safePrefs())?.setString(_editsKey, jsonEncode(state.toJson()));
  }
}

// --- Building the recorded timeline -------------------------------------------

/// Places you created while correcting a visit ("a new place here").
List<KnownPlace> _placesFromEdits(LocationEdits edits) {
  final places = <String, KnownPlace>{};
  for (final edit in edits.edits) {
    final id = edit.placeId;
    final point = edit.point;
    if (edit.kind != LocationEditKind.place || id == null || point == null) {
      continue;
    }
    places[id] = KnownPlace(
      id: id,
      point: point,
      semanticType: edit.semanticType,
    );
  }
  return places.values.toList();
}

/// Learns your speed on each mode from the Google history and your fixes.
TravelModeClassifier _trainClassifier(
  List<TimelineActivity> history,
  LocationEdits edits,
) {
  return TravelModeClassifier.train([
    for (final a in history)
      if (a.duration.inSeconds > 0)
        LabelledTrip(
          type: a.type,
          avgKmh: a.distanceMeters / 1000 / (a.duration.inSeconds / 3600),
        ),
    for (final e in edits.edits)
      if (e.kind == LocationEditKind.mode && e.type != null && e.avgKmh != null)
        LabelledTrip(type: e.type!, avgKmh: e.avgKmh!, weight: 3),
  ]);
}

/// The recorded timeline as visits and trips, places matched to ones you
/// know and modes chosen by what you usually do.
final recordedLocationProvider = Provider<LocationSummary>((ref) {
  final segments =
      ref.watch(recordedSegmentsProvider).value ?? const <RecordedSegment>[];
  if (segments.isEmpty) {
    return const LocationSummary(activities: [], placeVisits: []);
  }
  final imported = ref.watch(importedLocationProvider);
  final edits = ref.watch(locationEditsProvider);
  final names = ref.watch(placeNamesProvider);
  return buildRecordedSummary(
    segments: segments,
    knownPlaces: [
      ...knownPlacesFrom(imported.placeVisits, profile: imported.profile),
      ..._placesFromEdits(edits),
    ],
    classifier: _trainClassifier(imported.activities, edits),
    namedPlaceIds: {
      for (final e in names.entries)
        if (e.value.isNotEmpty) e.key,
    },
  );
});

// --- Places to pick from --------------------------------------------------------

class PlaceOption {
  const PlaceOption({
    required this.id,
    required this.point,
    required this.visits,
    this.semanticType,
  });

  final String id;
  final GeoPoint point;
  final int visits;
  final String? semanticType;
}

/// Every place in the timeline, for "this was actually at…".
final placeCatalogProvider = Provider<List<PlaceOption>>((ref) {
  final summary = ref.watch(locationSummaryProvider);
  final byId = <String, PlaceOption>{};
  for (final visit in summary.placeVisits) {
    final id = visit.placeId;
    final point = visit.point;
    if (id == null || point == null) continue;
    final previous = byId[id];
    byId[id] = PlaceOption(
      id: id,
      point: previous?.point ?? point,
      visits: (previous?.visits ?? 0) + 1,
      semanticType: previous?.semanticType ?? visit.semanticType,
    );
  }
  return byId.values.toList();
});
