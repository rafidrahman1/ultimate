import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';

/// Tiny trend line with a soft fill, used on Home tiles. Decorative: the
/// tile's own label carries the meaning, so it is hidden from semantics.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.width = 72,
    this.height = 26,
  });

  final List<double> values;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 700);

    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, reveal, _) => CustomPaint(
          size: Size(width, height),
          painter: _SparklinePainter(
            values: values,
            color: color,
            reveal: reveal,
            baseline: context.palette.border,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.reveal,
    required this.baseline,
  });

  final List<double> values;
  final Color color;
  final double reveal;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    const pad = 3.0;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final span = (maxValue - minValue).abs() < 1e-9 ? 1.0 : maxValue - minValue;

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          pad + (size.width - pad * 2) * i / (values.length - 1),
          size.height -
              pad -
              (size.height - pad * 2) * ((values[i] - minValue) / span),
        ),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final mid = Offset(
        (points[i - 1].dx + points[i].dx) / 2,
        (points[i - 1].dy + points[i].dy) / 2,
      );
      line.quadraticBezierTo(
        points[i - 1].dx,
        points[i - 1].dy,
        mid.dx,
        mid.dy,
      );
    }
    line.lineTo(points.last.dx, points.last.dy);

    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    if (reveal >= 1) {
      canvas.drawCircle(points.last, 2.6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.reveal != reveal ||
      old.color != color ||
      old.values != values ||
      old.baseline != baseline;
}
