import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ring split into proportional segments with small gaps, and an optional
/// centre widget. Decorative: callers give the figures their own labels.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    this.center,
    this.size = 120,
    this.strokeWidth = 14,
  });

  final List<double> values;
  final List<Color> colors;
  final Widget? center;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 700);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, reveal, child) => CustomPaint(
            painter: _DonutPainter(
              values: values,
              colors: colors,
              strokeWidth: strokeWidth,
              reveal: reveal,
            ),
            child: child,
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(strokeWidth + 6),
              child: center,
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.strokeWidth,
    required this.reveal,
  });

  final List<double> values;
  final List<Color> colors;
  final double strokeWidth;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + math.max(b, 0));
    if (total <= 0) return;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final gap = values.length > 1 ? 0.05 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = math.max(values[i], 0) / total * math.pi * 2 * reveal;
      if (sweep <= gap) continue;
      canvas.drawArc(
        arcRect,
        start + gap / 2,
        sweep - gap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = colors[i % colors.length],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values ||
      old.colors != colors ||
      old.reveal != reveal ||
      old.strokeWidth != strokeWidth;
}
