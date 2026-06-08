import 'package:flutter/material.dart';

/// Pushes [child] with a transition that expands from [sourceRect] to full screen.
class ExpandPageRoute<T> extends PageRoute<T> {
  ExpandPageRoute({
    required this.child,
    required this.sourceRect,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.backdropColor,
    this.backgroundAsset,
  });

  final Widget child;
  final Rect sourceRect;
  final BorderRadius borderRadius;
  final Color? backdropColor;
  final String? backgroundAsset;

  static const _duration = Duration(milliseconds: 420);

  @override
  Duration get transitionDuration => _duration;

  @override
  Duration get reverseTransitionDuration => _duration;

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final screenSize = MediaQuery.sizeOf(context);
    final endRect = Offset.zero & screenSize;
    final expandCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    final contentCurve = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.35, 1, curve: Curves.easeOut),
      reverseCurve: const Interval(0, 0.65, curve: Curves.easeIn),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([expandCurve, contentCurve]),
      child: child,
      builder: (context, child) {
        final rect = Rect.lerp(sourceRect, endRect, expandCurve.value)!;
        final radius = BorderRadius.lerp(
          borderRadius,
          BorderRadius.zero,
          expandCurve.value,
        )!;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fromRect(
              rect: rect,
              child: ClipRRect(
                borderRadius: radius,
                child: _ExpandBackdrop(
                  backgroundAsset: backgroundAsset,
                  color: backdropColor ?? Theme.of(context).colorScheme.surface,
                ),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: ClipRRect(
                borderRadius: radius,
                child: Opacity(
                  opacity: contentCurve.value,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExpandBackdrop extends StatelessWidget {
  const _ExpandBackdrop({
    required this.color,
    this.backgroundAsset,
  });

  final Color color;
  final String? backgroundAsset;

  @override
  Widget build(BuildContext context) {
    if (backgroundAsset != null) {
      return Image.asset(
        backgroundAsset!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return ColoredBox(color: color.withValues(alpha: 0.12));
  }
}

void pushExpandRoute(
  BuildContext context, {
  required Widget page,
  required Color backdropColor,
  String? backgroundAsset,
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(12)),
}) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    return;
  }

  final sourceRect = box.localToGlobal(Offset.zero) & box.size;
  Navigator.of(context).push(
    ExpandPageRoute<void>(
      sourceRect: sourceRect,
      borderRadius: borderRadius,
      backdropColor: backdropColor,
      backgroundAsset: backgroundAsset,
      child: page,
    ),
  );
}
