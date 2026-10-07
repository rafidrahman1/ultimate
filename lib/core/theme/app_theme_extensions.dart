part of 'app_theme.dart';

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

  /// Captions and hints. Dimmed a touch in dark mode; in light mode the
  /// secondary grey is already near the AA limit, so it is used as is.
  Color get textMuted => _scheme.brightness == Brightness.dark
      ? _scheme.onSurfaceVariant.withValues(alpha: 0.85)
      : _scheme.onSurfaceVariant;
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
    translucentSurface: Color(0x991C1C23),
    translucentBorder: Color(0x59282831),
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
