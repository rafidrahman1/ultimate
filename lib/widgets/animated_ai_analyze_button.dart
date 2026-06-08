import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'circular_app_bar_button.dart';

/// App-bar action for launching AI analysis — animated rotating color ring.
class AnimatedAiAnalyzeButton extends StatefulWidget {
  const AnimatedAiAnalyzeButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  State<AnimatedAiAnalyzeButton> createState() =>
      _AnimatedAiAnalyzeButtonState();
}

class _AnimatedAiAnalyzeButtonState extends State<AnimatedAiAnalyzeButton>
    with SingleTickerProviderStateMixin {
  static const _size = CircularAppBarButton.size;
  static const _iconSize = CircularAppBarButton.iconSize;
  static const _ringWidth = 2.0;

  late final AnimationController _controller;

  bool get _enabled => widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    if (_enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant AnimatedAiAnalyzeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_enabled && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) {
      return const CircularAppBarButton(
        icon: Icons.auto_awesome_outlined,
        onPressed: null,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final ringColors = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.primary,
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: _size,
          height: _size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: ringColors,
                transform: GradientRotation(
                  _controller.value * math.pi * 2,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(_ringWidth),
              child: child,
            ),
          ),
        );
      },
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: _size - _ringWidth * 2,
            height: _size - _ringWidth * 2,
            child: Icon(
              Icons.auto_awesome,
              size: _iconSize,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
