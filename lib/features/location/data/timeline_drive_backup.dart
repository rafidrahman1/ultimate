import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/auth/google_drive_client.dart';
import 'package:personal/features/location/data/location_insights_providers.dart';
import 'package:personal/features/location/data/location_service.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_export_writer.dart';
import 'package:personal/features/location/recording/recording_providers.dart';

const timelineDriveFolderName = appDriveFolderName;
const timelineDriveFileName = 'Timeline.json';

const _enabledKey = 'timeline_drive_backup_enabled_v1';
const _lastSavedKey = 'timeline_drive_backup_last_ms_v1';
const _lastHashKey = 'timeline_drive_backup_hash_v1';
const _askedKey = 'timeline_drive_backup_asked_v1';

/// How long after your last correction the file is re-saved, so a burst of
/// fixes is one upload.
const _editSaveDelay = Duration(seconds: 5);

/// Automatic saves at most this often; the recorder changes the timeline on
/// almost every refresh, and a multi-year file is tens of megabytes.
const _autoSaveInterval = Duration(hours: 1);

class TimelineDriveBackupState {
  const TimelineDriveBackupState({
    this.enabled = true,
    this.saving = false,
    this.lastSaved,
    this.error,
  });

  final bool enabled;
  final bool saving;
  final DateTime? lastSaved;

  /// Why the last save failed, until one succeeds.
  final String? error;

  TimelineDriveBackupState copyWith({
    bool? enabled,
    bool? saving,
    DateTime? lastSaved,
    String? Function()? error,
  }) => TimelineDriveBackupState(
    enabled: enabled ?? this.enabled,
    saving: saving ?? this.saving,
    lastSaved: lastSaved ?? this.lastSaved,
    error: error == null ? this.error : error(),
  );
}

/// Saves the whole timeline (Google export + what the phone recorded, with
/// your corrections) to Google Drive as `Timeline/Timeline.json`, in the
/// Google export format.
final timelineDriveBackupProvider =
    NotifierProvider<TimelineDriveBackupController, TimelineDriveBackupState>(
      TimelineDriveBackupController.new,
    );

class TimelineDriveBackupController extends Notifier<TimelineDriveBackupState> {
  Future<void>? _hydrated;
  Future<bool>? _running;
  bool _rerun = false;
  Timer? _editTimer;

  @override
  TimelineDriveBackupState build() {
    _hydrated = _hydrate();
    // Your corrections go to Drive soon after you make them.
    ref.listen(locationEditsProvider, (_, _) => _scheduleEditSave());
    ref.listen(placeNamesProvider, (_, _) => _scheduleEditSave());
    ref.onDispose(() => _editTimer?.cancel());
    return const TimelineDriveBackupState();
  }

  void _scheduleEditSave() {
    _editTimer?.cancel();
    _editTimer = Timer(_editSaveDelay, () async {
      await _hydrated;
      if (state.enabled) await _save(interactive: false, force: false);
    });
  }

  Future<void> _hydrate() async {
    final prefs = await safePrefs();
    final ms = prefs?.getInt(_lastSavedKey);
    state = state.copyWith(
      // On unless you turned it off, so data you already have is saved
      // after updating.
      enabled: prefs?.getBool(_enabledKey) ?? true,
      lastSaved: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  /// Turning it on asks for Drive access and saves straight away; returns
  /// false if that failed (see [TimelineDriveBackupState.error]).
  Future<bool> setEnabled(bool enabled) async {
    await _hydrated;
    state = state.copyWith(enabled: enabled, error: () => null);
    await (await safePrefs())?.setBool(_enabledKey, enabled);
    if (!enabled) return true;
    return saveNow();
  }

  /// Saves now, asking for sign-in / Drive access if needed.
  Future<bool> saveNow() => _save(interactive: true, force: true);

  /// Called on refresh: saves quietly if on, changed, and not saved lately.
  Future<void> saveIfDue() async {
    await _hydrated;
    if (!state.enabled) return;
    final last = state.lastSaved;
    if (last != null && clock.now().difference(last) < _autoSaveInterval) {
      return;
    }
    await _save(interactive: false, force: false);
  }

  /// One save at a time; asked for while one runs, it saves once more after,
  /// so a correction made mid-upload isn't left out.
  Future<bool> _save({required bool interactive, required bool force}) {
    if (_running != null) {
      _rerun = true;
      return _running!;
    }
    return _running = () async {
      var ok = await _doSave(interactive: interactive, force: force);
      while (_rerun) {
        _rerun = false;
        ok = await _doSave(interactive: false, force: false);
      }
      return ok;
    }().whenComplete(() => _running = null);
  }

  Future<bool> _doSave({required bool interactive, required bool force}) async {
    state = state.copyWith(saving: true);
    try {
      // Let both sources finish loading, so a cold start never saves a
      // timeline missing the export or the recording.
      await ref.read(importedLocationProvider.notifier).restoreFromCache();
      await ref.read(recordedSegmentsProvider.future);
      final summary = ref.read(locationSummaryProvider);
      if (!summary.hasAnyData) {
        state = state.copyWith(saving: false, error: () => null);
        return true;
      }
      final encoded = await _encodeInBackground(
        summary,
        ref.read(placeNamesProvider),
      );

      final prefs = await safePrefs();
      if (!force && prefs?.getInt(_lastHashKey) == encoded.hash) {
        state = state.copyWith(saving: false, error: () => null);
        return true;
      }

      final drive = GoogleDriveClient();
      Future<bool> upload({required bool interactive}) => drive.saveTextFile(
        folderName: timelineDriveFolderName,
        fileName: timelineDriveFileName,
        bytes: encoded.bytes,
        interactive: interactive,
      );
      var saved = await upload(interactive: interactive);
      // Drive write access is new in this version: ask for it once, the
      // first time a save needs it, rather than waiting for a tap.
      if (!saved && !interactive && !(prefs?.getBool(_askedKey) ?? false)) {
        await prefs?.setBool(_askedKey, true);
        saved = await upload(interactive: true);
      }
      if (!saved) {
        state = state.copyWith(
          saving: false,
          error: () => 'Google Drive access is needed. Tap "Save now".',
        );
        return false;
      }
      final now = clock.now();
      await prefs?.setInt(_lastSavedKey, now.millisecondsSinceEpoch);
      await prefs?.setInt(_lastHashKey, encoded.hash);
      state = state.copyWith(saving: false, lastSaved: now, error: () => null);
      return true;
    } catch (error) {
      AppLog.warn('Saving the timeline to Google Drive failed: $error');
      final message = error is FormatException ? error.message : '$error';
      state = state.copyWith(saving: false, error: () => message);
      return false;
    }
  }
}

typedef _Encoded = ({Uint8List bytes, int hash});

Future<_Encoded> _encodeInBackground(
  LocationSummary summary,
  Map<String, String> placeNames,
) => Isolate.run(() {
  final bytes = utf8.encode(
    encodeTimelineExport(summary, placeNames: placeNames),
  );
  return (bytes: bytes, hash: fnv1a32(bytes));
});

/// A stable content hash (unlike [Object.hashCode] across runs).
int fnv1a32(List<int> bytes) {
  var hash = 0x811c9dc5;
  for (final b in bytes) {
    hash = ((hash ^ b) * 0x01000193) & 0xffffffff;
  }
  return hash;
}
