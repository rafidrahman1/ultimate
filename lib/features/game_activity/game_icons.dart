import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal/core/storage/prefs.dart';

const _prefsKey = 'game_icons_v1';

/// The icons the AI may choose from, keyed by the name it replies with.
const gameIconCatalog = <String, IconData>{
  'shooter': Icons.gps_fixed_rounded,
  'war': Icons.military_tech_rounded,
  'racing': Icons.sports_motorsports_rounded,
  'driving': Icons.directions_car_rounded,
  'flying': Icons.flight_rounded,
  'space': Icons.rocket_launch_rounded,
  'football': Icons.sports_soccer_rounded,
  'basketball': Icons.sports_basketball_rounded,
  'cricket': Icons.sports_cricket_rounded,
  'tennis': Icons.sports_tennis_rounded,
  'fighting': Icons.sports_mma_rounded,
  'platformer': Icons.directions_run_rounded,
  'puzzle': Icons.extension_rounded,
  'strategy': Icons.psychology_rounded,
  'rpg': Icons.shield_rounded,
  'fantasy': Icons.auto_fix_high_rounded,
  'adventure': Icons.explore_rounded,
  'horror': Icons.dark_mode_rounded,
  'survival': Icons.forest_rounded,
  'sandbox': Icons.construction_rounded,
  'simulation': Icons.agriculture_rounded,
  'card': Icons.style_rounded,
  'board': Icons.casino_rounded,
  'music': Icons.music_note_rounded,
  'other': Icons.sports_esports_rounded,
};

/// Game name → catalog key, as chosen by the AI. Games without an entry keep
/// the plain initial tile.
final gameIconsProvider =
    NotifierProvider<GameIconsNotifier, Map<String, String>>(
      GameIconsNotifier.new,
    );

class GameIconsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    _hydrate();
    return const {};
  }

  Future<void> _hydrate() async {
    final raw = (await safePrefs())?.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      state = {
        for (final e in decoded.entries)
          if (e.value is String && gameIconCatalog.containsKey(e.value))
            '${e.key}': e.value as String,
        ...state,
      };
    } on FormatException {
      // Corrupt entry: start over.
    }
  }

  Future<void> assign(Map<String, String> picks) async {
    if (picks.isEmpty) return;
    state = {...state, ...picks};
    await (await safePrefs())?.setString(_prefsKey, jsonEncode(state));
  }
}
