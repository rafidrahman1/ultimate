import 'package:flutter/material.dart';

abstract final class AppColors {
  static const seed = Color(0xFF1E3A5F);
  static const health = Color(0xFFE53935);
  static const expenses = Color(0xFF2E7D32);
  static const location = Color(0xFFEF6C00);
  static const accent = Color(0xFF1565C0);
  static const prompt = Color(0xFF6A1B9A);
  static const result = Color(0xFF00897B);
  static const gameActivity = Color(0xFF7B1FA2);
}

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      color: colorScheme.surfaceContainerLowest,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: colorScheme.surface,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
