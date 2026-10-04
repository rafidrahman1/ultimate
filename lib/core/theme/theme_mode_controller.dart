import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/prefs.dart';

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
      _ => null,
    };
    if (mode != null && mode != state) {
      _memoryFallback = mode;
      state = mode;
    }
  }

  void setDarkMode(bool enabled) {
    state = enabled ? ThemeMode.dark : ThemeMode.light;
    _memoryFallback = state;
    unawaited(_persist());
  }

  void toggle() {
    setDarkMode(state != ThemeMode.dark);
  }

  Future<void> _persist() async {
    await (await safePrefs())?.setString(
      _themeModeKey,
      state == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}
