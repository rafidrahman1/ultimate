import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/auth/google_drive_client.dart';
import 'package:personal/features/location/data/location_cache.dart';
import 'package:personal/features/location/data/location_edits.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_drive_backup.dart'
    show timelineDriveFileName, timelineDriveFolderName;
import 'package:personal/features/location/data/timeline_file_finder.dart';
import 'package:personal/features/location/data/timeline_merge.dart';
import 'package:personal/features/location/recording/recording_providers.dart';

/// The Drive file last loaded, so an unchanged one isn't downloaded again.
const _driveVersionKey = 'timeline_drive_import_version_v1';

/// The whole timeline everything else reads: the Google export, then what
/// the phone recorded after it, with your corrections applied.
final locationSummaryProvider = Provider<LocationSummary>((ref) {
  final merged = mergeLocationSources(
    ref.watch(importedLocationProvider),
    ref.watch(recordedLocationProvider),
  );
  return applyLocationEdits(merged, ref.watch(locationEditsProvider));
});

/// The last imported Google Timeline export only.
final importedLocationProvider =
    StateNotifierProvider<LocationSummaryNotifier, LocationSummary>((ref) {
      final notifier = LocationSummaryNotifier(ref);
      unawaited(notifier.restoreFromCache());
      return notifier;
    });

class LocationSummaryNotifier extends StateNotifier<LocationSummary> {
  LocationSummaryNotifier(this._ref)
    : super(const LocationSummary(activities: [], placeVisits: []));

  final Ref _ref;
  Future<void>? _restoreFuture;

  /// Idempotent and safe to await from multiple callers: they all resolve
  /// once the same underlying cache read completes, so a caller that awaits
  /// this can rely on `state` reflecting the cache (if any) afterwards.
  Future<void> restoreFromCache() => _restoreFuture ??= _restoreFromCache();

  Future<void> _restoreFromCache() async {
    final cached = await LocationCache.load();
    if (cached != null && cached.activities.isNotEmpty) {
      state = cached;
    }
  }

  void _commit(LocationSummary summary) {
    state = summary;
    if (summary.hasAnyData) {
      unawaited(LocationCache.save(summary));
    }
  }

  /// Loads `Timeline.json` from the Google Drive "Timeline" folder, the
  /// one place it's read from. Skips the download when the file hasn't
  /// changed since it was last loaded.
  Future<void> loadAuto({bool interactiveSignIn = false}) async {
    await restoreFromCache();
    final prefs = await safePrefs();
    final lastVersion = state.hasAnyData && !state.isLegacyCache
        ? prefs?.getString(_driveVersionKey)
        : null;
    final file =
        await GoogleDriveClient(
          accountService: _ref.read(googleAccountServiceProvider),
        ).fetchNewestBytesInFolder(
          folderName: timelineDriveFolderName,
          nameQuery: "name contains 'Timeline' and name contains '.json'",
          fileNameMatches: isTimelineExportFileName,
          fileDescription: timelineDriveFileName,
          interactiveSignIn: interactiveSignIn,
          unlessVersion: lastVersion,
        );
    if (file == null) return;
    await _setSummaryFromBytes(file.bytes, fileName: file.fileName);
    await prefs?.setString(_driveVersionKey, file.version);
  }

  Future<void> importFromPicker() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return;

    final bytes = await _readFileBytes(file);
    final name = file.name;
    if (bytes == null || bytes.isEmpty) {
      throw FormatException('Could not read "$name".');
    }

    await _setSummaryFromBytes(bytes, fileName: name);
  }

  void clear() {
    state = const LocationSummary(activities: [], placeVisits: []);
    unawaited(LocationCache.clear());
    unawaited(safePrefs().then((p) => p?.remove(_driveVersionKey)));
  }

  Future<void> _setSummaryFromBytes(
    Uint8List bytes, {
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw FormatException('File "$fileName" is empty.');
    }
    final LocationSummary summary;
    try {
      summary = await parseTimelineExportInBackground(
        bytes,
        fileName: fileName,
      );
    } on FormatException catch (e) {
      throw FormatException(
        '"$fileName" is not a Timeline export: ${e.message}',
      );
    }
    if (!summary.hasAnyData) {
      throw FormatException(
        'No activity or place-visit segments found in "$fileName".',
      );
    }
    _commit(summary);
  }

  Future<Uint8List?> _readFileBytes(PlatformFile file) async {
    return file.readAsBytes();
  }
}
