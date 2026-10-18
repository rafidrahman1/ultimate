import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:motohealth/core/theme/app_theme.dart';

class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Floating "liquid glass" bar: content scrolls underneath a blurred,
/// translucent pill with a bright rim. The selected item sits in a glass
/// capsule that slides (and stretches a little, like a drop of liquid) to
/// follow [position], so it can track a swiping page view. Use with
/// `Scaffold.extendBody`.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.position,
    required this.onSelected,
  });

  final List<GlassNavItem> items;

  /// Fractional index of the selected item, e.g. 1.5 midway between two.
  final ValueListenable<double> position;
  final ValueChanged<int> onSelected;

  /// Height of the bar itself, without the safe area or outer margin.
  static const height = 68.0;
  static const _padding = 6.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    final fill = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: dark ? 0.16 : 0.62),
        Colors.white.withValues(alpha: dark ? 0.05 : 0.30),
      ],
    );
    final rim = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: dark ? 0.45 : 0.95),
        Colors.white.withValues(alpha: dark ? 0.06 : 0.25),
        Colors.white.withValues(alpha: dark ? 0.20 : 0.55),
      ],
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        // Slides up and fades in the first time the bar appears.
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 40),
              child: child,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.45 : 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: CustomPaint(
                  foregroundPainter: _RimPainter(rim),
                  child: Container(
                    height: height,
                    padding: const EdgeInsets.all(_padding),
                    decoration: BoxDecoration(gradient: fill),
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final slot = box.maxWidth / items.length;
                        return ValueListenableBuilder<double>(
                          valueListenable: position,
                          builder: (context, pos, _) {
                            // 0 on an item, 1 halfway between two.
                            final between =
                                (pos - pos.roundToDouble()).abs() * 2;
                            final stretch =
                                math.sin(between * math.pi / 2) * 14;
                            return Stack(
                              children: [
                                Positioned(
                                  left: pos * slot - stretch / 2,
                                  width: slot + stretch,
                                  top: 0,
                                  bottom: 0,
                                  child: _Capsule(accent: accent, dark: dark),
                                ),
                                for (var i = 0; i < items.length; i++)
                                  Positioned(
                                    left: i * slot,
                                    width: slot,
                                    top: 0,
                                    bottom: 0,
                                    child: _Item(
                                      item: items[i],
                                      emphasis: (1 - (pos - i).abs()).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      accent: accent,
                                      onTap: () => onSelected(i),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Capsule extends StatelessWidget {
  const _Capsule({required this.accent, required this.dark});

  final Color accent;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.22 : 0.85),
            Colors.white.withValues(alpha: dark ? 0.08 : 0.40),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.30 : 0.9),
        ),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 12),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.item,
    required this.emphasis,
    required this.accent,
    required this.onTap,
  });

  final GlassNavItem item;

  /// 1 when this item is the selected one, easing to 0 as it moves away.
  final double emphasis;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color.lerp(
      theme.colorScheme.onSurfaceVariant,
      accent,
      emphasis,
    )!;
    return Semantics(
      button: true,
      selected: emphasis > 0.5,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, -2 * emphasis),
              child: Transform.scale(
                scale: 1 + 0.18 * emphasis,
                child: Icon(
                  emphasis > 0.5 ? item.selectedIcon : item.icon,
                  color: color,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: emphasis > 0.5 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 1px gradient edge that catches the light, drawn over the glass.
class _RimPainter extends CustomPainter {
  _RimPainter(this.gradient);

  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(0.5),
        Radius.circular(size.height / 2),
      ),
      Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.gradient != gradient;
}
