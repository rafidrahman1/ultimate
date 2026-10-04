import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/prefs.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/location/location_service.dart';
import 'package:personal/features/location/place_stats.dart';

const _placeNamesKey = 'place_names_v1';

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
    unawaited(_hydrate());
    return const {};
  }

  Future<void> _hydrate() async {
    final raw = (await safePrefs())?.getString(_placeNamesKey);
    if (raw == null || raw.isEmpty) return;
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

  Future<void> _persist() async {
    await (await safePrefs())?.setString(_placeNamesKey, jsonEncode(state));
  }
}

/// What to call [place]: the user's name, else Home/Work, else generic.
String placeDisplayName(PlaceStat place, Map<String, String> names) {
  for (final id in place.placeIds) {
    final custom = names[id];
    if (custom != null && custom.isNotEmpty) return custom;
  }
  return switch (place.kind) {
    PlaceKind.home => 'Home',
    PlaceKind.work => 'Work',
    PlaceKind.other => 'Unnamed place',
  };
}
