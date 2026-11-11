import 'package:flutter/material.dart';
import 'package:personal/shared/navigation/fade_scale_page_route.dart';

part 'app_theme_extensions.dart';
part 'app_theme_tokens.dart';

// The look is an almanac: warm ink in the dark, paper in the light, a serif
// display face for titles and headline figures. The interface itself stays
// neutral (the primary colour is the ink), so colour always means data: a
// source (DomainColors) or a state (StatusColors).

abstract final class _DarkPalette {
  static const background = Color(0xFF100F0D);
  static const surfaceContainerLow = Color(0xFF161513);
  static const surfaceBase = Color(0xFF1C1B18);
  static const surfaceContainerHigh = Color(0xFF262420);
  static const surfaceOverlay = Color(0xFF34312B);
  static const hairline = Color(0xFF2A2824);
  static const textPrimary = Color(0xFFF2EEE6);
  static const textSecondary = Color(0xFFA9A397);
  static const primary = Color(0xFFF2EEE6);
  static const onPrimary = Color(0xFF161513);
}

abstract final class _LightPalette {
  static const background = Color(0xFFF4EFE6);
  static const surfaceContainerLow = Color(0xFFEFE9DE);
  static const surfaceBase = Color(0xFFFBF8F2);
  static const surfaceContainerHigh = Color(0xFFEAE3D6);
  static const surfaceOverlay = Color(0xFFDDD5C6);
  static const hairline = Color(0xFFE3DCCE);
  static const textPrimary = Color(0xFF1B1A17);
  static const textSecondary = Color(0xFF655F54);
  static const primary = Color(0xFF1B1A17);
}

abstract final class _DarkDomainAccents {
  static const health = Color(0xFF8CC5A2);
  static const expenses = Color(0xFFE391A9);
  static const mobility = Color(0xFFE0A268);
  static const gameActivity = Color(0xFFB7A1E0);
  static const calendar = Color(0xFF7FB2DE);
  static const screenTime = Color(0xFF6CC4C4);
}

abstract final class _LightDomainAccents {
  static const health = Color(0xFF2F6B4F);
  static const expenses = Color(0xFF9A3F58);
  static const mobility = Color(0xFF8F5718);
  static const gameActivity = Color(0xFF6A4B95);
  static const calendar = Color(0xFF2C5C8F);
  static const screenTime = Color(0xFF1F6E73);
}

abstract final class _DarkStatusAccents {
  static const good = Color(0xFF86D39C);
  static const warning = Color(0xFFE8BE55);
  static const critical = Color(0xFFF07A6A);
}

abstract final class _LightStatusAccents {
  static const good = Color(0xFF2A7D49);
  static const warning = Color(0xFF8A5A00);
  static const critical = Color(0xFFB93A2B);
}

final class _ResolvedTheme {
  const _ResolvedTheme({
    required this.brightness,
    required this.background,
    required this.surfaceContainerLow,
    required this.surfaceBase,
    required this.surfaceContainerHigh,
    required this.surfaceOverlay,
    required this.textPrimary,
    required this.textSecondary,
    required this.domainColors,
    required this.colorScheme,
    required this.onPrimary,
  });

  final Brightness brightness;
  final Color background;
  final Color surfaceContainerLow;
  final Color surfaceBase;
  final Color surfaceContainerHigh;
  final Color surfaceOverlay;
  final Color textPrimary;
  final Color textSecondary;
  final DomainColors domainColors;
  final ColorScheme colorScheme;
  final Color onPrimary;

  TextTheme get textTheme {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
        height: 1.1,
        letterSpacing: -1.5,
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
        height: 1.1,
        letterSpacing: -1.2,
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      displaySmall: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
        height: 1.1,
        letterSpacing: -0.9,
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      headlineLarge: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
        height: 1.2,
        letterSpacing: -0.7,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
        height: 1.2,
        letterSpacing: -0.5,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineSmall: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
        height: 1.2,
        letterSpacing: -0.4,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: AppFonts.display,
        fontFamilyFallback: AppFonts.displayFallback,
        height: 1.2,
        letterSpacing: -0.3,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textSecondary,
      ),
    );
  }

  ShapeBorder get cardShape {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
    );
  }
}

abstract final class AppTheme {
  static const _darkResolved = _ResolvedTheme(
    brightness: Brightness.dark,
    background: _DarkPalette.background,
    surfaceContainerLow: _DarkPalette.surfaceContainerLow,
    surfaceBase: _DarkPalette.surfaceBase,
    surfaceContainerHigh: _DarkPalette.surfaceContainerHigh,
    surfaceOverlay: _DarkPalette.surfaceOverlay,
    textPrimary: _DarkPalette.textPrimary,
    textSecondary: _DarkPalette.textSecondary,
    domainColors: DomainColors.dark,
    onPrimary: _DarkPalette.onPrimary,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: _DarkPalette.primary,
      onPrimary: _DarkPalette.onPrimary,
      primaryContainer: Color(0xFF2E2B26),
      onPrimaryContainer: _DarkPalette.textPrimary,
      secondary: _DarkDomainAccents.health,
      onSecondary: _DarkPalette.background,
      secondaryContainer: Color(0xFF1F3329),
      onSecondaryContainer: _DarkDomainAccents.health,
      tertiary: _DarkDomainAccents.mobility,
      onTertiary: _DarkPalette.background,
      tertiaryContainer: Color(0xFF3A2B19),
      onTertiaryContainer: _DarkDomainAccents.mobility,
      error: _DarkStatusAccents.critical,
      onError: _DarkPalette.background,
      errorContainer: Color(0xFF45201B),
      onErrorContainer: _DarkStatusAccents.critical,
      surface: _DarkPalette.surfaceBase,
      onSurface: _DarkPalette.textPrimary,
      surfaceDim: _DarkPalette.background,
      surfaceBright: _DarkPalette.surfaceOverlay,
      surfaceContainerLowest: _DarkPalette.background,
      surfaceContainerLow: _DarkPalette.surfaceContainerLow,
      surfaceContainer: _DarkPalette.surfaceBase,
      surfaceContainerHigh: _DarkPalette.surfaceContainerHigh,
      surfaceContainerHighest: _DarkPalette.surfaceOverlay,
      onSurfaceVariant: _DarkPalette.textSecondary,
      outline: _DarkPalette.hairline,
      outlineVariant: _DarkPalette.hairline,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: _DarkPalette.textPrimary,
      onInverseSurface: _DarkPalette.background,
      inversePrimary: _LightPalette.primary,
    ),
  );

  static const _lightResolved = _ResolvedTheme(
    brightness: Brightness.light,
    background: _LightPalette.background,
    surfaceContainerLow: _LightPalette.surfaceContainerLow,
    surfaceBase: _LightPalette.surfaceBase,
    surfaceContainerHigh: _LightPalette.surfaceContainerHigh,
    surfaceOverlay: _LightPalette.surfaceOverlay,
    textPrimary: _LightPalette.textPrimary,
    textSecondary: _LightPalette.textSecondary,
    domainColors: DomainColors.light,
    onPrimary: _LightPalette.surfaceBase,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: _LightPalette.primary,
      onPrimary: _LightPalette.surfaceBase,
      primaryContainer: Color(0xFFE6DFD1),
      onPrimaryContainer: _LightPalette.primary,
      secondary: _LightDomainAccents.health,
      onSecondary: _LightPalette.surfaceBase,
      secondaryContainer: Color(0xFFD9E6DA),
      onSecondaryContainer: _LightDomainAccents.health,
      tertiary: _LightDomainAccents.mobility,
      onTertiary: _LightPalette.surfaceBase,
      tertiaryContainer: Color(0xFFF0E0C8),
      onTertiaryContainer: _LightDomainAccents.mobility,
      error: _LightStatusAccents.critical,
      onError: _LightPalette.surfaceBase,
      errorContainer: Color(0xFFF3D9D3),
      onErrorContainer: _LightStatusAccents.critical,
      surface: _LightPalette.surfaceBase,
      onSurface: _LightPalette.textPrimary,
      surfaceDim: _LightPalette.background,
      surfaceBright: _LightPalette.surfaceBase,
      surfaceContainerLowest: _LightPalette.background,
      surfaceContainerLow: _LightPalette.surfaceContainerLow,
      surfaceContainer: _LightPalette.surfaceBase,
      surfaceContainerHigh: _LightPalette.surfaceContainerHigh,
      surfaceContainerHighest: _LightPalette.surfaceOverlay,
      onSurfaceVariant: _LightPalette.textSecondary,
      outline: _LightPalette.hairline,
      outlineVariant: _LightPalette.hairline,
      shadow: Colors.black26,
      scrim: Colors.black45,
      inverseSurface: _LightPalette.textPrimary,
      onInverseSurface: _LightPalette.surfaceBase,
      inversePrimary: _DarkPalette.primary,
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
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Roboto'],
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeScalePageTransitionsBuilder(),
          TargetPlatform.iOS: FadeScalePageTransitionsBuilder(),
          TargetPlatform.windows: FadeScalePageTransitionsBuilder(),
          TargetPlatform.macOS: FadeScalePageTransitionsBuilder(),
          TargetPlatform.linux: FadeScalePageTransitionsBuilder(),
        },
      ),
      extensions: [
        domainColors,
        resolved.brightness == Brightness.dark
            ? SurfaceChrome.dark
            : SurfaceChrome.light,
        resolved.brightness == Brightness.dark
            ? StatusColors.dark
            : StatusColors.light,
      ],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        titleSpacing: AppSpacing.screen,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: resolved.background,
        foregroundColor: resolved.textPrimary,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.display,
          fontFamilyFallback: AppFonts.displayFallback,
          fontSize: 22,
          letterSpacing: -0.3,
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
        backgroundColor: resolved.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.display,
          fontFamilyFallback: AppFonts.displayFallback,
          fontSize: 22,
          letterSpacing: -0.3,
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
        fillColor: resolved.surfaceContainerHigh,
        labelStyle: TextStyle(color: resolved.textSecondary),
        hintStyle: TextStyle(color: resolved.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          borderSide: BorderSide(color: resolved.surfaceOverlay),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          borderSide: BorderSide(color: colorScheme.error),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        iconColor: resolved.textSecondary,
        textColor: resolved.textPrimary,
      ),
      iconTheme: IconThemeData(color: resolved.textSecondary),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: resolved.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.card),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: resolved.surfaceOverlay,
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: resolved.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: resolved.surfaceOverlay,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          color: resolved.textPrimary,
        ),
        side: BorderSide(color: resolved.surfaceOverlay),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
    );
  }
}
