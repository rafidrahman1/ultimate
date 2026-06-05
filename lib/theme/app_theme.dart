import 'package:flutter/material.dart';

abstract final class AppColors {
  static const seed = Color(0xFF1E3A5F);
  static const health = Color(0xFFE53935);
  static const expenses = Color(0xFF45BA4A);
  static const location = Color(0xFFFF7300);
  static const accent = Color(0xFF1565C0);
  static const prompt = Color(0xFF6A1B9A);
  static const result = Color(0xFF00DAC3);
  static const gameActivity = Color(0xFFC23EFF);
  static const calendar = Color(0xFF1686FF);
}

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.seed, brightness: brightness);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(centerTitle: true, elevation: 0, scrolledUnderElevation: 1, backgroundColor: colorScheme.surface, foregroundColor: colorScheme.onSurface),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      color: colorScheme.surfaceContainerLowest,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );
}

/// Shared surface and text colors derived from the active [ColorScheme].
final class AppPalette {
  const AppPalette._(this._scheme);

  final ColorScheme _scheme;

  static AppPalette of(BuildContext context) =>
      AppPalette._(Theme.of(context).colorScheme);

  Color get canvas => _scheme.surface;
  Color get card => _scheme.surfaceContainerLow;
  Color get cardElevated => _scheme.surfaceContainerHigh;
  Color get border => _scheme.outlineVariant;
  Color get textPrimary => _scheme.onSurface;
  Color get textSecondary => _scheme.onSurfaceVariant;
  Color get textMuted => _scheme.onSurfaceVariant.withValues(alpha: 0.72);
  Color get warning => _scheme.tertiary;
  Color get accent => _scheme.primary;
  Color get accentAlt => AppColors.result;
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}
