import 'package:personal/features/location/data/timeline_activity.dart';

/// One timeline from a Google export and what the phone recorded.
///
/// Up to the end of the export, Google's version is used (it has had more
/// to work with); after that, the recorded one. So importing a newer export
/// replaces recorded days with Google's, and your corrections still apply
/// because they match by time.
LocationSummary mergeLocationSources(
  LocationSummary imported,
  LocationSummary recorded,
) {
  if (!recorded.hasAnyData) return imported;
  if (!imported.hasAnyData) {
    return LocationSummary(
      activities: recorded.activities,
      placeVisits: recorded.placeVisits,
      profile: recorded.profile,
    );
  }

  final cut = importedCoverageEnd(imported)!;
  bool after(DateTime end) => end.isAfter(cut);
  DateTime clamp(DateTime start) => start.isBefore(cut) ? cut : start;

  return LocationSummary(
    activities: [
      ...imported.activities,
      for (final a in recorded.activities)
        if (after(a.endTime)) a.copyWith(startTime: clamp(a.startTime)),
    ],
    placeVisits: [
      ...imported.placeVisits,
      for (final v in recorded.placeVisits)
        if (after(v.endTime)) v.copyWith(startTime: clamp(v.startTime)),
    ],
    profile: imported.profile.isEmpty ? recorded.profile : imported.profile,
    trips: imported.trips,
    placeNames: imported.placeNames,
    isLegacyCache: imported.isLegacyCache,
    fileName: imported.fileName,
  );
}

/// When the export's last visit or trip ends, or null without one.
DateTime? importedCoverageEnd(LocationSummary imported) {
  DateTime? latest;
  for (final a in imported.activities) {
    if (latest == null || a.endTime.isAfter(latest)) latest = a.endTime;
  }
  for (final v in imported.placeVisits) {
    if (latest == null || v.endTime.isAfter(latest)) latest = v.endTime;
  }
  return latest;
}
