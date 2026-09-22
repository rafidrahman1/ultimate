import 'package:flutter/material.dart';

abstract final class _DarkPalette {
  static const background = Color(0xFF000000);
  static const surfaceContainerLow = Color(0xFF0A0A0A);
  static const surfaceBase = Color(0xFF121212);
  static const surfaceContainerHigh = Color(0xFF1C1C1C);
  static const surfaceOverlay = Color(0xFF262626);
  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFFA3A3A3);
  static const primary = Color(0xFFADA9E8);
  static const onPrimary = Color(0xFF221F45);
}

abstract final class _LightPalette {
  static const background = Color(0xFFFAF8F5);
  static const surfaceContainerLow = Color(0xFFF5F3EF);
  static const surfaceBase = Color(0xFFFFFFFF);
  static const surfaceContainerHigh = Color(0xFFF0EDE7);
  static const surfaceOverlay = Color(0xFFEBE7E0);
  static const textPrimary = Color(0xFF16151C);
  static const textSecondary = Color(0xFF6C6875);
  static const primary = Color(0xFF1C1B5E);
}

abstract final class _DarkDomainAccents {
  static const health = Color(0xFF6FBFA6);
  static const expenses = Color(0xFFD98CA3);
  static const mobility = Color(0xFFD9A26B);
  static const gameActivity = Color(0xFFB29BD9);
  static const calendar = Color(0xFF6FA8D9);
}

abstract final class _LightDomainAccents {
  static const health = Color(0xFF2E6B54);
  static const expenses = Color(0xFF8A4A52);
  static const mobility = Color(0xFF9C6B3E);
  static const gameActivity = Color(0xFF6B4C8C);
  static const calendar = Color(0xFF2E5A8A);
}

abstract final class _DarkStatusAccents {
  static const good = Color(0xFF7ED99A);
  static const warning = Color(0xFFE8B84D);
  static const critical = Color(0xFFE8677D);
}

abstract final class _LightStatusAccents {
  static const good = Color(0xFF2E8F52);
  static const warning = Color(0xFFA6740A);
  static const critical = Color(0xFFC23B4F);
}

@immutable
final class DomainColors extends ThemeExtension<DomainColors> {
  const DomainColors({
    required this.health,
    required this.expenses,
    required this.mobility,
    required this.gameActivity,
    required this.calendar,
  });

  final Color health;
  final Color expenses;
  final Color mobility;
  final Color gameActivity;
  final Color calendar;

  static const dark = DomainColors(
    health: _DarkDomainAccents.health,
    expenses: _DarkDomainAccents.expenses,
    mobility: _DarkDomainAccents.mobility,
    gameActivity: _DarkDomainAccents.gameActivity,
    calendar: _DarkDomainAccents.calendar,
  );

  static const light = DomainColors(
    health: _LightDomainAccents.health,
    expenses: _LightDomainAccents.expenses,
    mobility: _LightDomainAccents.mobility,
    gameActivity: _LightDomainAccents.gameActivity,
    calendar: _LightDomainAccents.calendar,
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
    Color? calendar,
  }) {
    return DomainColors(
      health: health ?? this.health,
      expenses: expenses ?? this.expenses,
      mobility: mobility ?? this.mobility,
      gameActivity: gameActivity ?? this.gameActivity,
      calendar: calendar ?? this.calendar,
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
      calendar: Color.lerp(calendar, other.calendar, t)!,
    );
  }
}

@immutable
final class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.good,
    required this.warning,
    required this.critical,
    required this.neutral,
  });

  final Color good;
  final Color warning;
  final Color critical;
  final Color neutral;

  static const dark = StatusColors(
    good: _DarkStatusAccents.good,
    warning: _DarkStatusAccents.warning,
    critical: _DarkStatusAccents.critical,
    neutral: _DarkPalette.textSecondary,
  );

  static const light = StatusColors(
    good: _LightStatusAccents.good,
    warning: _LightStatusAccents.warning,
    critical: _LightStatusAccents.critical,
    neutral: _LightPalette.textSecondary,
  );

  static StatusColors of(BuildContext context) {
    final extension = Theme.of(context).extension<StatusColors>();
    if (extension != null) {
      return extension;
    }

    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  @override
  StatusColors copyWith({
    Color? good,
    Color? warning,
    Color? critical,
    Color? neutral,
  }) {
    return StatusColors(
      good: good ?? this.good,
      warning: warning ?? this.warning,
      critical: critical ?? this.critical,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) {
      return this;
    }

    if (t <= 0) {
      return this;
    }

    if (t >= 1) {
      return other;
    }

    return StatusColors(
      good: Color.lerp(good, other.good, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}

extension StatusColorsContext on BuildContext {
  StatusColors get statusColors => StatusColors.of(this);
}

final class AppPalette {
  const AppPalette._(this._scheme, this._domainColors, this._statusColors);

  final ColorScheme _scheme;
  final DomainColors _domainColors;
  final StatusColors _statusColors;

  static AppPalette of(BuildContext context) => AppPalette._(
    Theme.of(context).colorScheme,
    DomainColors.of(context),
    StatusColors.of(context),
  );

  Color get canvas => _scheme.surfaceDim;
  Color get card => _scheme.surface;
  Color get cardElevated => _scheme.surfaceContainerHigh;
  Color get border => _scheme.outline;
  Color get textPrimary => _scheme.onSurface;
  Color get textSecondary => _scheme.onSurfaceVariant;
  Color get textMuted => _scheme.onSurfaceVariant.withValues(alpha: 0.72);
  Color get warning => _statusColors.warning;
  Color get statusGood => _statusColors.good;
  Color get statusCritical => _statusColors.critical;
  Color get statusNeutral => _statusColors.neutral;
  Color get accent => _scheme.primary;
  Color get health => _domainColors.health;
  Color get expenses => _domainColors.expenses;
  Color get mobility => _domainColors.mobility;
  Color get gameActivity => _domainColors.gameActivity;
  Color get calendar => _domainColors.calendar;
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}

extension DomainColorsContext on BuildContext {
  DomainColors get domainColors => DomainColors.of(this);
}

@immutable
final class SurfaceChrome extends ThemeExtension<SurfaceChrome> {
  const SurfaceChrome({
    required this.translucentSurface,
    required this.translucentBorder,
  });

  final Color translucentSurface;
  final Color translucentBorder;

  static const dark = SurfaceChrome(
    translucentSurface: Color(0x991C1C1C),
    translucentBorder: Color(0x591C1C1C),
  );

  static const light = SurfaceChrome(
    translucentSurface: Color(0xB8EBE7E0),
    translucentBorder: Color(0x59EBE7E0),
  );

  static SurfaceChrome of(BuildContext context) {
    final extension = Theme.of(context).extension<SurfaceChrome>();
    if (extension != null) {
      return extension;
    }

    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  @override
  SurfaceChrome copyWith({
    Color? translucentSurface,
    Color? translucentBorder,
  }) {
    return SurfaceChrome(
      translucentSurface: translucentSurface ?? this.translucentSurface,
      translucentBorder: translucentBorder ?? this.translucentBorder,
    );
  }

  @override
  SurfaceChrome lerp(ThemeExtension<SurfaceChrome>? other, double t) {
    if (other is! SurfaceChrome) {
      return this;
    }

    if (t <= 0) {
      return this;
    }

    if (t >= 1) {
      return other;
    }

    return SurfaceChrome(
      translucentSurface: Color.lerp(
        translucentSurface,
        other.translucentSurface,
        t,
      )!,
      translucentBorder: Color.lerp(
        translucentBorder,
        other.translucentBorder,
        t,
      )!,
    );
  }
}

extension SurfaceChromeContext on BuildContext {
  SurfaceChrome get surfaceChrome => SurfaceChrome.of(this);
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
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
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
      primaryContainer: Color(0xFF38335F),
      onPrimaryContainer: Color(0xFFD9D6FF),
      secondary: _DarkDomainAccents.health,
      onSecondary: _DarkPalette.background,
      secondaryContainer: Color(0xFF0D3D32),
      onSecondaryContainer: _DarkDomainAccents.health,
      tertiary: _DarkDomainAccents.mobility,
      onTertiary: _DarkPalette.background,
      tertiaryContainer: Color(0xFF3D2A14),
      onTertiaryContainer: _DarkDomainAccents.mobility,
      error: _DarkStatusAccents.critical,
      onError: _DarkPalette.background,
      errorContainer: Color(0xFF4A1620),
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
      error: _LightStatusAccents.critical,
      onError: _LightPalette.surfaceBase,
      errorContainer: Color(0xFFF6DEDF),
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
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Roboto'],
      textTheme: textTheme,
      primaryTextTheme: textTheme,
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
        backgroundColor: resolved.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
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
        fillColor: resolved.surfaceContainerHigh,
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
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

/// `card`: default radius for chrome and controls — dialogs, bottom sheets,
/// snackbars, chips, buttons, inputs, list tiles (matches the global
/// `CardThemeData` default).
///
/// `cardLarge`: top-level content cards that sit directly in a scrolling
/// dashboard and carry their own visual weight — e.g. domain cards, the
/// discrepancy matrix container, header/summary cards.
abstract final class AppRadii {
  static const card = 12.0;
  static const cardLarge = 16.0;
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

/// Background-tint alpha values for badges, muted containers, and chip
/// fills. Not for foreground/stroke/shadow alphas — those serve a different
/// job and stay as local literals.
abstract final class AppOpacity {
  static const subtle = 0.10;
  static const medium = 0.16;
  static const strong = 0.22;
}
