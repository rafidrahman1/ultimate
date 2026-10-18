import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/storage/prefs.dart';

const _themeModeKey = 'theme_mode_v1';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  static ThemeMode _memoryFallback = ThemeMode.dark;

  @override
  ThemeMode build() {
    unawaited(_hydrate());
    return _memoryFallback;
  }

  Future<void> _hydrate() async {
    final stored = (await safePrefs())?.getString(_themeModeKey);
    final mode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
    if (mode != null && mode != state) {
      _memoryFallback = mode;
      state = mode;
    }
  }

  void setMode(ThemeMode mode) {
    state = mode;
    _memoryFallback = mode;
    unawaited(_persist());
  }

  /// Flips between light and dark based on what is currently on screen, so it
  /// also behaves when the mode is "follow system".
  void toggle(Brightness current) {
    setMode(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> _persist() async {
    await (await safePrefs())?.setString(_themeModeKey, switch (state) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    });
  }
}
