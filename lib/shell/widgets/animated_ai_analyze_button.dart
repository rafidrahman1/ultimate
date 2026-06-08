import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:personal/shared/widgets/circular_app_bar_button.dart';

/// App-bar action for launching AI analysis — animated rotating color ring.
class AnimatedAiAnalyzeButton extends StatefulWidget {
  const AnimatedAiAnalyzeButton({
    super.key,
    required this.onPressed,
    this.isAnalyzing = false,
  });

  final void Function(BuildContext buttonContext)? onPressed;
  final bool isAnalyzing;

  @override
  State<AnimatedAiAnalyzeButton> createState() =>
      _AnimatedAiAnalyzeButtonState();
}

class _AnimatedAiAnalyzeButtonState extends State<AnimatedAiAnalyzeButton>
    with TickerProviderStateMixin {
  static const _size = CircularAppBarButton.size;
  static const _iconSize = CircularAppBarButton.iconSize;
  static const _idleRingWidth = 2.0;
  static const _analyzingRingWidth = 3.0;
  static const _blinkCycle = Duration(milliseconds: 4200);

  late final AnimationController _ringController;
  late final AnimationController _blinkController;

  bool get _showAnimatedRing => widget.isAnalyzing || widget.onPressed != null;

  Duration get _ringDuration => widget.isAnalyzing
      ? const Duration(milliseconds: 280)
      : const Duration(milliseconds: 2800);

  double get _ringWidth =>
      widget.isAnalyzing ? _analyzingRingWidth : _idleRingWidth;

  @override
  void initState() {
    super.initState();
    _ringController =
        AnimationController(vsync: this, duration: _ringDuration);
    _blinkController =
        AnimationController(vsync: this, duration: _blinkCycle);
    _syncAnimations(restart: false);
  }

  @override
  void didUpdateWidget(covariant AnimatedAiAnalyzeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final analyzingChanged = oldWidget.isAnalyzing != widget.isAnalyzing;
    if (analyzingChanged) {
      _ringController.duration = _ringDuration;
    }
    _syncAnimations(restart: analyzingChanged);
  }

  void _syncAnimations({required bool restart}) {
    if (_showAnimatedRing) {
      if (restart) {
        _ringController
          ..reset()
          ..repeat();
      } else if (!_ringController.isAnimating) {
        _ringController.repeat();
      }
    } else {
      _ringController.stop();
      _ringController.value = 0;
    }

    if (widget.isAnalyzing) {
      if (restart || !_blinkController.isAnimating) {
        _blinkController
          ..reset()
          ..repeat();
      }
    } else {
      _blinkController.stop();
      _blinkController.value = 0;
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  /// Slow cat-eye blink: languid close, brief hold, languid open, long rest.
  double _catEyeOpacity(double t) {
    if (t < 0.28) {
      return 1 - Curves.easeInCubic.transform(t / 0.28) * 0.78;
    }
    if (t < 0.34) {
      return 0.22;
    }
    if (t < 0.62) {
      return 0.22 +
          Curves.easeOutCubic.transform((t - 0.34) / 0.28) * 0.78;
    }
    return 1;
  }

  double _iconOpacity() {
    if (!widget.isAnalyzing) return 1;
    return _catEyeOpacity(_blinkController.value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_showAnimatedRing) {
      return const CircularAppBarButton(
        icon: Icons.auto_awesome_outlined,
        onPressed: null,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final ringColors = widget.isAnalyzing
        ? [
            colorScheme.primary,
            colorScheme.tertiary,
            colorScheme.secondary,
            colorScheme.primary,
          ]
        : [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
          ];
    final innerSize = _size - _ringWidth * 2;

    return Builder(
      builder: (buttonContext) {
        return AnimatedBuilder(
          animation: Listenable.merge([_ringController, _blinkController]),
          builder: (context, _) {
            return SizedBox(
              width: _size,
              height: _size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: ringColors,
                    transform: GradientRotation(
                      _ringController.value * math.pi * 2,
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(_ringWidth),
                  child: Material(
                    color: colorScheme.surfaceContainerHighest,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.isAnalyzing
                          ? null
                          : () => widget.onPressed?.call(buttonContext),
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: innerSize,
                        height: innerSize,
                        child: Opacity(
                          opacity: _iconOpacity(),
                          child: Icon(
                            Icons.auto_awesome,
                            size: _iconSize,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
