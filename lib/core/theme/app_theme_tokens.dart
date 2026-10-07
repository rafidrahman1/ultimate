part of 'app_theme.dart';

/// `card`: default radius for chrome and controls — dialogs, bottom sheets,
/// snackbars, chips, buttons, inputs, list tiles (matches the global
/// `CardThemeData` default).
///
/// `cardLarge`: top-level content cards that sit directly in a scrolling
/// dashboard and carry their own visual weight — e.g. domain cards, the
/// discrepancy matrix container, header/summary cards.
///
/// `xs`: tiny marks — chart bars, swatches, progress tracks.
/// `small`: badges, icon chips, and small containers nested inside cards.
/// `pill`: fully rounded chips, pills, and the bottom nav.
abstract final class AppRadii {
  static const xs = 4.0;
  static const small = 8.0;
  static const card = 12.0;
  static const cardLarge = 16.0;
  static const pill = 999.0;
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;

  /// Horizontal gutter between screen content and the display edge.
  static const screen = 20.0;
}

/// Background-tint alpha values for badges, muted containers, and chip
/// fills. Not for foreground/stroke/shadow alphas — those serve a different
/// job and stay as local literals.
abstract final class AppOpacity {
  static const subtle = 0.10;
  static const medium = 0.16;
  static const strong = 0.22;
}

/// Layout constants shared by screens.
abstract final class AppLayout {
  /// Bottom clearance so scrolling content stays above the floating nav pill.
  static const navPillClearance = 90.0;

  /// Widest a content column grows on tablets / landscape.
  static const maxContentWidth = 720.0;
}

/// Expressive text styles that sit on top of the Material scale.
extension AppTextStyles on BuildContext {
  /// Large tabular-figure number for headline metrics.
  TextStyle get statDisplay =>
      Theme.of(this).textTheme.headlineMedium!.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Small uppercase overline used above groups of content.
  TextStyle get sectionLabel => Theme.of(this).textTheme.labelSmall!.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: Theme.of(this).colorScheme.onSurfaceVariant,
  );
}
