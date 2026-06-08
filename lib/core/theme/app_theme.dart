import 'package:flutter/material.dart';

abstract final class _DarkPalette {
  static const background = Color(0xFF0F0E17);
  static const surfaceBase = Color(0xFF1A1829);
  static const surfaceOverlay = Color(0xFF242238);
  static const textPrimary = Color(0xFFFFF5FF);
  static const textSecondary = Color(0xFF9F9BA9);
  static const primary = Color(0xFFCEFF00);
}

abstract final class _LightPalette {
  static const background = Color(0xFFFAF8F5);
  static const surfaceBase = Color(0xFFFFFFFF);
  static const surfaceOverlay = Color(0xFFEBE7E0);
  static const textPrimary = Color(0xFF16151C);
  static const textSecondary = Color(0xFF6C6875);
  static const primary = Color(0xFF1C1B5E);
}

abstract final class _DarkDomainAccents {
  static const health = Color(0xFF00FFC2);
  static const expenses = Color(0xFFFF2E93);
  static const mobility = Color(0xFFFF9F43);
  static const gameActivity = Color(0xFFDA77FF);
}

abstract final class _LightDomainAccents {
  static const health = Color(0xFF1A4D3A);
  static const expenses = Color(0xFF651714);
  static const mobility = Color(0xFFB35412);
  static const gameActivity = Color(0xFF7B1FA2);
}

@immutable
final class DomainColors extends ThemeExtension<DomainColors> {
  const DomainColors({
    required this.health,
    required this.expenses,
    required this.mobility,
    required this.gameActivity,
  });

  final Color health;
  final Color expenses;
  final Color mobility;
  final Color gameActivity;

  static const dark = DomainColors(
    health: _DarkDomainAccents.health,
    expenses: _DarkDomainAccents.expenses,
    mobility: _DarkDomainAccents.mobility,
    gameActivity: _DarkDomainAccents.gameActivity,
  );

  static const light = DomainColors(
    health: _LightDomainAccents.health,
    expenses: _LightDomainAccents.expenses,
    mobility: _LightDomainAccents.mobility,
    gameActivity: _LightDomainAccents.gameActivity,
  );

  static DomainColors of(BuildContext context) {
    final extension = Theme.of(context).extension<DomainColors>();
    if (extension != null) {
      return extension;
    }

    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  @override
  DomainColors copyWith({
    Color? health,
    Color? expenses,
    Color? mobility,
    Color? gameActivity,
  }) {
    return DomainColors(
      health: health ?? this.health,
      expenses: expenses ?? this.expenses,
      mobility: mobility ?? this.mobility,
      gameActivity: gameActivity ?? this.gameActivity,
    );
  }

  @override
  DomainColors lerp(ThemeExtension<DomainColors>? other, double t) {
    if (other is! DomainColors) {
      return this;
    }

    if (t <= 0) {
      return this;
    }

    if (t >= 1) {
      return other;
    }

    return DomainColors(
      health: Color.lerp(health, other.health, t)!,
      expenses: Color.lerp(expenses, other.expenses, t)!,
      mobility: Color.lerp(mobility, other.mobility, t)!,
      gameActivity: Color.lerp(gameActivity, other.gameActivity, t)!,
    );
  }
}

final class AppPalette {
  const AppPalette._(this._scheme, this._domainColors);

  final ColorScheme _scheme;
  final DomainColors _domainColors;

  static AppPalette of(BuildContext context) => AppPalette._(
        Theme.of(context).colorScheme,
        DomainColors.of(context),
      );

  Color get canvas => _scheme.surfaceDim;
  Color get card => _scheme.surface;
  Color get cardElevated => _scheme.surfaceContainerHigh;
  Color get border => _scheme.outline;
  Color get textPrimary => _scheme.onSurface;
  Color get textSecondary => _scheme.onSurfaceVariant;
  Color get textMuted => _scheme.onSurfaceVariant.withValues(alpha: 0.72);
  Color get warning => _scheme.tertiary;
  Color get accent => _scheme.primary;
  Color get accentAlt => _scheme.primary;
  Color get health => _domainColors.health;
  Color get expenses => _domainColors.expenses;
  Color get mobility => _domainColors.mobility;
  Color get gameActivity => _domainColors.gameActivity;
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}

extension DomainColorsContext on BuildContext {
  DomainColors get domainColors => DomainColors.of(this);
}

final class _ResolvedTheme {
  const _ResolvedTheme({
    required this.brightness,
    required this.background,
    required this.surfaceBase,
    required this.surfaceOverlay,
    required this.textPrimary,
    required this.textSecondary,
    required this.domainColors,
    required this.colorScheme,
    required this.onPrimary,
  });

  final Brightness brightness;
  final Color background;
  final Color surfaceBase;
  final Color surfaceOverlay;
  final Color textPrimary;
  final Color textSecondary;
  final DomainColors domainColors;
  final ColorScheme colorScheme;
  final Color onPrimary;

  TextTheme get textTheme {
    return TextTheme(
      displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, color: textPrimary),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400, color: textPrimary),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: textPrimary),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: textPrimary),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: textPrimary),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textSecondary),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary),
    );
  }

  ShapeBorder get cardShape {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: surfaceOverlay,
        width: 1,
      ),
    );
  }
}

abstract final class AppTheme {
  static const _darkResolved = _ResolvedTheme(
    brightness: Brightness.dark,
    background: _DarkPalette.background,
    surfaceBase: _DarkPalette.surfaceBase,
    surfaceOverlay: _DarkPalette.surfaceOverlay,
    textPrimary: _DarkPalette.textPrimary,
    textSecondary: _DarkPalette.textSecondary,
    domainColors: DomainColors.dark,
    onPrimary: _DarkPalette.background,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: _DarkPalette.primary,
      onPrimary: _DarkPalette.background,
      primaryContainer: Color(0xFF2A3310),
      onPrimaryContainer: _DarkPalette.primary,
      secondary: _DarkDomainAccents.health,
      onSecondary: _DarkPalette.background,
      secondaryContainer: Color(0xFF0D3D32),
      onSecondaryContainer: _DarkDomainAccents.health,
      tertiary: _DarkDomainAccents.mobility,
      onTertiary: _DarkPalette.background,
      tertiaryContainer: Color(0xFF3D2A14),
      onTertiaryContainer: _DarkDomainAccents.mobility,
      error: _DarkDomainAccents.expenses,
      onError: _DarkPalette.background,
      errorContainer: Color(0xFF3D1230),
      onErrorContainer: _DarkDomainAccents.expenses,
      surface: _DarkPalette.surfaceBase,
      onSurface: _DarkPalette.textPrimary,
      surfaceDim: _DarkPalette.background,
      surfaceBright: _DarkPalette.surfaceOverlay,
      surfaceContainerLowest: _DarkPalette.background,
      surfaceContainerLow: _DarkPalette.surfaceBase,
      surfaceContainer: _DarkPalette.surfaceBase,
      surfaceContainerHigh: _DarkPalette.surfaceOverlay,
      surfaceContainerHighest: _DarkPalette.surfaceOverlay,
      onSurfaceVariant: _DarkPalette.textSecondary,
      outline: _DarkPalette.surfaceOverlay,
      outlineVariant: _DarkPalette.surfaceOverlay,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: _DarkPalette.textPrimary,
      onInverseSurface: _DarkPalette.background,
      inversePrimary: _DarkPalette.primary,
    ),
  );

  static const _lightResolved = _ResolvedTheme(
    brightness: Brightness.light,
    background: _LightPalette.background,
    surfaceBase: _LightPalette.surfaceBase,
    surfaceOverlay: _LightPalette.surfaceOverlay,
    textPrimary: _LightPalette.textPrimary,
    textSecondary: _LightPalette.textSecondary,
    domainColors: DomainColors.light,
    onPrimary: _LightPalette.surfaceBase,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: _LightPalette.primary,
      onPrimary: _LightPalette.surfaceBase,
      primaryContainer: Color(0xFFE8E7F5),
      onPrimaryContainer: _LightPalette.primary,
      secondary: _LightDomainAccents.health,
      onSecondary: _LightPalette.surfaceBase,
      secondaryContainer: Color(0xFFD8EBE2),
      onSecondaryContainer: _LightDomainAccents.health,
      tertiary: _LightDomainAccents.mobility,
      onTertiary: _LightPalette.surfaceBase,
      tertiaryContainer: Color(0xFFF5E4D4),
      onTertiaryContainer: _LightDomainAccents.mobility,
      error: _LightDomainAccents.expenses,
      onError: _LightPalette.surfaceBase,
      errorContainer: Color(0xFFF5E0DF),
      onErrorContainer: _LightDomainAccents.expenses,
      surface: _LightPalette.surfaceBase,
      onSurface: _LightPalette.textPrimary,
      surfaceDim: _LightPalette.background,
      surfaceBright: _LightPalette.surfaceBase,
      surfaceContainerLowest: _LightPalette.background,
      surfaceContainerLow: _LightPalette.surfaceBase,
      surfaceContainer: _LightPalette.surfaceBase,
      surfaceContainerHigh: _LightPalette.surfaceOverlay,
      surfaceContainerHighest: _LightPalette.surfaceOverlay,
      onSurfaceVariant: _LightPalette.textSecondary,
      outline: _LightPalette.surfaceOverlay,
      outlineVariant: _LightPalette.surfaceOverlay,
      shadow: Colors.black26,
      scrim: Colors.black45,
      inverseSurface: _LightPalette.textPrimary,
      onInverseSurface: _LightPalette.surfaceBase,
      inversePrimary: _LightPalette.primary,
    ),
  );

  static ThemeData get darkTheme => _buildTheme(_darkResolved);

  static ThemeData get lightTheme => _buildTheme(_lightResolved);

  static ThemeData _buildTheme(_ResolvedTheme resolved) {
    final textTheme = resolved.textTheme;
    final colorScheme = resolved.colorScheme;
    final domainColors = resolved.domainColors;

    return ThemeData(
      useMaterial3: true,
      brightness: resolved.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: resolved.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [domainColors],
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: resolved.background,
        foregroundColor: resolved.textPrimary,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: resolved.textPrimary,
        ),
        iconTheme: IconThemeData(color: resolved.textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: resolved.surfaceBase,
        surfaceTintColor: Colors.transparent,
        shape: resolved.cardShape,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: resolved.surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(
            color: resolved.surfaceOverlay,
            width: 1,
          ),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: resolved.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: resolved.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: resolved.surfaceOverlay,
        labelStyle: TextStyle(color: resolved.textSecondary),
        hintStyle: TextStyle(color: resolved.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: resolved.surfaceOverlay),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: domainColors.expenses),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: domainColors.expenses),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: resolved.surfaceOverlay,
        thickness: 1,
        space: 1,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: resolved.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 2,
        highlightElevation: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: resolved.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconColor: resolved.textSecondary,
        textColor: resolved.textPrimary,
      ),
      iconTheme: IconThemeData(color: resolved.textSecondary),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: resolved.surfaceBase,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          side: BorderSide(
            color: resolved.surfaceOverlay,
            width: 1,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: resolved.surfaceOverlay,
        contentTextStyle: TextStyle(color: resolved.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: resolved.surfaceOverlay,
        labelStyle: TextStyle(color: resolved.textPrimary),
        side: BorderSide(color: resolved.surfaceOverlay),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
