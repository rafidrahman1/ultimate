import 'dart:ui';

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
/// translucent pill with a bright rim, and the selected item sits in its own
/// glass capsule. Use with `Scaffold.extendBody`.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<GlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Height of the bar itself, without the safe area or outer margin.
  static const height = 68.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;
    final tint = dark ? Colors.white : Colors.white;

    final fill = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        tint.withValues(alpha: dark ? 0.16 : 0.62),
        tint.withValues(alpha: dark ? 0.05 : 0.30),
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(gradient: fill),
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _Item(
                            item: items[i],
                            selected: i == selectedIndex,
                            accent: accent,
                            dark: dark,
                            onTap: () => onSelected(i),
                          ),
                        ),
                    ],
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

class _Item extends StatelessWidget {
  const _Item({
    required this.item,
    required this.selected,
    required this.accent,
    required this.dark,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final Color accent;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? accent : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: dark ? 0.22 : 0.85),
                      Colors.white.withValues(alpha: dark ? 0.08 : 0.40),
                    ],
                  )
                : null,
            border: selected
                ? Border.all(
                    color: Colors.white.withValues(alpha: dark ? 0.30 : 0.9),
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
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
