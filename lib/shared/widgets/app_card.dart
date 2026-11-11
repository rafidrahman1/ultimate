import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';

enum AppCardTier {
  /// Recessed surface for secondary content.
  flat,

  /// Default content card: a tonal surface, no border.
  raised,

  /// Flat accent wash for the one card that leads a screen.
  hero,
}

/// The single card surface used across the app. Prefer this over ad-hoc
/// `Container` + `BorderRadius` + `Border.all` combinations.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.tier = AppCardTier.raised,
    this.accent,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.onLongPress,
    this.radius = AppRadii.cardLarge,
  });

  final Widget child;
  final AppCardTier tier;

  /// Tint for [AppCardTier.hero]; defaults to the theme primary.
  final Color? accent;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final borderRadius = BorderRadius.circular(radius);
    final tint = accent ?? palette.accent;

    final decoration = switch (tier) {
      AppCardTier.flat => BoxDecoration(
        color: palette.canvas,
        borderRadius: borderRadius,
        border: Border.all(color: palette.border),
      ),
      // Tonal: the fill alone lifts it off the canvas.
      AppCardTier.raised => BoxDecoration(
        color: palette.card,
        borderRadius: borderRadius,
      ),
      // One flat wash of the source colour; no border, no gradient.
      AppCardTier.hero => BoxDecoration(
        color: Color.alphaBlend(tint.withValues(alpha: 0.15), palette.card),
        borderRadius: borderRadius,
      ),
    };

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
