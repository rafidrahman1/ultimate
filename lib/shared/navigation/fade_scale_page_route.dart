import 'package:flutter/material.dart';

/// Pushes [child] with a smooth fade + slight scale-up transition.
class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  FadeScalePageRoute({required Widget page})
    : super(
        transitionDuration: _duration,
        reverseTransitionDuration: _duration,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final scale = Tween(begin: 0.92, end: 1.0).animate(curve);

          return Stack(
            fit: StackFit.expand,
            children: [
              FadeTransition(
                opacity: curve,
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.1)),
              ),
              FadeTransition(
                opacity: curve,
                child: ScaleTransition(
                  scale: scale,
                  child: RepaintBoundary(child: child),
                ),
              ),
            ],
          );
        },
      );

  static const _duration = Duration(milliseconds: 300);
}

Future<T?> pushFadeScaleRoute<T>(
  BuildContext context, {
  required Widget page,
}) {
  return Navigator.of(context).push<T>(FadeScalePageRoute<T>(page: page));
}
