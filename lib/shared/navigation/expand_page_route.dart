import 'dart:math' as math;

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
                clipBehavior: Clip.hardEdge,
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minWidth: screenSize.width,
                  maxWidth: screenSize.width,
                  minHeight: screenSize.height,
                  maxHeight: screenSize.height,
                  child: Opacity(opacity: contentCurve.value, child: child),
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
  const _ExpandBackdrop({required this.color, this.backgroundAsset});

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

Future<double> _measureChildHeight(
  BuildContext context, {
  required Widget child,
  required double width,
}) async {
  final key = GlobalKey();
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (overlayContext) => MediaQuery(
      data: MediaQuery.of(context),
      child: Theme(
        data: Theme.of(context),
        child: Positioned(
          left: -10000,
          top: 0,
          width: width,
          child: KeyedSubtree(key: key, child: child),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  await WidgetsBinding.instance.endOfFrame;
  await WidgetsBinding.instance.endOfFrame;
  final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  final height = renderBox?.hasSize == true
      ? renderBox!.size.height.toDouble()
      : 300.0;
  entry.remove();
  return height.ceilToDouble();
}

/// Expands from [context]'s bounds into a compact anchored card.
Future<T?> pushExpandCardRoute<T>(
  BuildContext context, {
  required Widget child,
  required Color backdropColor,
  double cardWidth = 340,
  double? cardHeight,
  double gapFromSource = 8,
  EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 16),
  BorderRadius targetBorderRadius = const BorderRadius.all(Radius.circular(16)),
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final mediaQuery = MediaQuery.maybeOf(context);
  if (box == null || !box.hasSize || mediaQuery == null) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => Dialog(child: child),
    );
  }

  final sourceRect = box.localToGlobal(Offset.zero) & box.size;
  final screenSize = mediaQuery.size;
  final padding = mediaQuery.padding;
  final width = math.min(cardWidth, screenSize.width - margin.horizontal);
  final resolvedHeight =
      cardHeight ??
      await _measureChildHeight(context, child: child, width: width);
  final left = (sourceRect.right - width).clamp(
    margin.left,
    screenSize.width - width - margin.right,
  );
  var top = sourceRect.bottom + gapFromSource;
  final maxBottom = screenSize.height - padding.bottom - margin.bottom;
  if (top + resolvedHeight > maxBottom) {
    top = (sourceRect.top - gapFromSource - resolvedHeight).clamp(
      padding.top + margin.top,
      maxBottom - resolvedHeight,
    );
  }
  final targetRect = Rect.fromLTWH(left, top, width, resolvedHeight);

  if (!context.mounted) return null;

  return Navigator.of(context).push<T>(
    ExpandCardRoute<T>(
      sourceRect: sourceRect,
      targetRect: targetRect,
      sourceBorderRadius: BorderRadius.circular(sourceRect.shortestSide / 2),
      targetBorderRadius: targetBorderRadius,
      backdropColor: backdropColor,
      child: child,
    ),
  );
}

/// Pushes a route that expands from a small source rect into [targetRect].
class ExpandCardRoute<T> extends PageRoute<T> {
  ExpandCardRoute({
    required this.child,
    required this.sourceRect,
    required this.targetRect,
    required this.sourceBorderRadius,
    required this.targetBorderRadius,
    this.backdropColor,
  });

  final Widget child;
  final Rect sourceRect;
  final Rect targetRect;
  final BorderRadius sourceBorderRadius;
  final BorderRadius targetBorderRadius;
  final Color? backdropColor;

  static const _duration = Duration(milliseconds: 380);

  @override
  Duration get transitionDuration => _duration;

  @override
  Duration get reverseTransitionDuration => _duration;

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => Colors.black38;

  @override
  String? get barrierLabel => 'Dismiss';

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
    final expandCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final contentCurve = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.38, 1, curve: Curves.easeOut),
      reverseCurve: const Interval(0, 0.62, curve: Curves.easeIn),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([expandCurve, contentCurve]),
      child: child,
      builder: (context, child) {
        final rect = Rect.lerp(sourceRect, targetRect, expandCurve.value)!;
        final radius = BorderRadius.lerp(
          sourceBorderRadius,
          targetBorderRadius,
          expandCurve.value,
        )!;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fromRect(
              rect: rect,
              child: ClipRRect(
                borderRadius: radius,
                clipBehavior: Clip.hardEdge,
                child: ColoredBox(
                  color:
                      backdropColor ??
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: ClipRRect(
                borderRadius: radius,
                clipBehavior: Clip.hardEdge,
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minWidth: targetRect.width,
                  maxWidth: targetRect.width,
                  minHeight: targetRect.height,
                  maxHeight: targetRect.height,
                  child: Opacity(opacity: contentCurve.value, child: child),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<T?> pushExpandRoute<T>(
  BuildContext context, {
  required Widget page,
  required Color backdropColor,
  String? backgroundAsset,
  BorderRadius? borderRadius,
}) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) {
    return Navigator.of(
      context,
    ).push<T>(MaterialPageRoute<T>(builder: (_) => page));
  }

  final sourceRect = box.localToGlobal(Offset.zero) & box.size;
  final resolvedRadius =
      borderRadius ?? BorderRadius.circular(sourceRect.shortestSide / 2);

  return Navigator.of(context).push<T>(
    ExpandPageRoute<T>(
      sourceRect: sourceRect,
      borderRadius: resolvedRadius,
      backdropColor: backdropColor,
      backgroundAsset: backgroundAsset,
      child: page,
    ),
  );
}
