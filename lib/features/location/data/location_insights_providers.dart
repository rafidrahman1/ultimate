import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/prefs.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/location/analysis/place_stats.dart';
import 'package:personal/features/location/data/location_service.dart';
import 'package:personal/features/prompts/personal_info_firestore_service.dart';

const _placeNamesKey = 'place_names_v1';
const _placeNamesUpdatedKey = 'place_names_updated_at_v1';

/// Place insights for the selected analysis period. Built from the whole
/// export so "new places" can see the history before the period.
final locationInsightsProvider = Provider<LocationInsights>((ref) {
  final period = ref.watch(analysisPeriodProvider);
  final summary = ref.watch(locationSummaryProvider);
  return computeLocationInsights(
    summary,
    period.dataMonthStart,
    period.dataMonthEnd,
  );
});

/// Month-by-month travel across the entire export.
final locationHistoryProvider = Provider<List<MonthlyLocationRow>>((ref) {
  return buildMonthlyHistory(ref.watch(locationSummaryProvider));
});

/// Names the user gave to places. The export has no place names, so unnamed
/// places are labelled by what they are (Home, Work) or left generic.
final placeNamesProvider =
    NotifierProvider<PlaceNamesController, Map<String, String>>(
      PlaceNamesController.new,
    );

class PlaceNamesController extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    unawaited(_hydrate().then((_) => syncFromCloud()));
    // After the app data is cleared the user is signed out, so the first sync
    // finds nobody; sync again as soon as they sign back in.
    ref.listen(authStateProvider, (previous, next) {
      if (next.valueOrNull != null &&
          next.valueOrNull?.uid != previous?.valueOrNull?.uid) {
        unawaited(syncFromCloud());
      }
    });
    return const {};
  }

  bool _changed = false;

  /// Takes the names saved with the personal information when they are newer
  /// than these, or uploads these when they are newer (or not saved yet).
  Future<void> syncFromCloud() async {
    final user = ref.read(googleAccountServiceProvider).currentUser;
    if (user == null) return;
    try {
      final cloud = await ref
          .read(personalInfoFirestoreServiceProvider)
          .loadPlaceNames(user.uid);
      final prefs = await safePrefs();
      final localMillis = prefs?.getInt(_placeNamesUpdatedKey);
      final cloudAt = cloud?.updatedAt;
      final cloudNewer =
          cloud != null &&
          cloudAt != null &&
          (localMillis == null || cloudAt.millisecondsSinceEpoch > localMillis);
      if (cloudNewer) {
        state = cloud.names;
        await prefs?.setString(_placeNamesKey, jsonEncode(state));
        await prefs?.setInt(
          _placeNamesUpdatedKey,
          cloudAt.millisecondsSinceEpoch,
        );
      } else if (state.isNotEmpty && (cloud == null || localMillis != null)) {
        await _push();
      }
    } catch (error) {
      AppLog.warn('Could not sync place names with the cloud: $error');
    }
  }

  Future<void> _push() async {
    final user = ref.read(googleAccountServiceProvider).currentUser;
    if (user == null) return;
    try {
      final at = await ref
          .read(personalInfoFirestoreServiceProvider)
          .savePlaceNames(user.uid, state);
      if (at != null) {
        await (await safePrefs())?.setInt(
          _placeNamesUpdatedKey,
          at.millisecondsSinceEpoch,
        );
      }
    } catch (error) {
      AppLog.warn('Could not save place names to the cloud: $error');
    }
  }

  Future<void> _hydrate() async {
    final raw = (await safePrefs())?.getString(_placeNamesKey);
    if (raw == null || raw.isEmpty || _changed) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      state = {
        for (final entry in decoded.entries)
          if (entry.value is String)
            entry.key.toString(): entry.value as String,
      };
    } on FormatException {
      // A corrupt value just means no names yet.
    }
  }

  /// Names every id of [place]. An empty [name] removes the label.
  void rename(PlaceStat place, String name) {
    final trimmed = name.trim();
    final next = Map<String, String>.of(state);
    for (final id in place.placeIds) {
      if (trimmed.isEmpty) {
        next.remove(id);
      } else {
        next[id] = trimmed;
      }
    }
    state = next;
    unawaited(_persist());
  }

  /// Applies several names at once (AI suggestions). Places the user already
  /// named are left alone.
  void suggest(Map<PlaceStat, String> suggestions) {
    final next = Map<String, String>.of(state);
    for (final entry in suggestions.entries) {
      if (entry.key.placeIds.any((id) => (next[id] ?? '').isNotEmpty)) continue;
      for (final id in entry.key.placeIds) {
        next[id] = entry.value;
      }
    }
    state = next;
    unawaited(_persist());
  }

  Future<void> _persist() async {
    _changed = true;
    final prefs = await safePrefs();
    await prefs?.setString(_placeNamesKey, jsonEncode(state));
    await prefs?.setInt(
      _placeNamesUpdatedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    await _push();
  }
}
