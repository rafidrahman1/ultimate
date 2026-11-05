import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';

/// Small line chart with dashed gridlines, dotted data points and three
/// left-hand axis labels (max / mid / min). Needs at least two [values];
/// draws nothing otherwise. Oldest value first.
class MiniLineChart extends StatelessWidget {
  const MiniLineChart({
    super.key,
    required this.values,
    required this.color,
    required this.format,
    this.height = 72,
  });

  final List<double> values;
  final Color color;
  final String Function(double value) format;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);
    final palette = context.palette;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 700);
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelSmall!.copyWith(color: palette.textMuted, fontSize: 10);

    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, reveal, _) => CustomPaint(
          size: Size(double.infinity, height),
          painter: _MiniLinePainter(
            values: values,
            color: color,
            grid: palette.border,
            labelStyle: labelStyle,
            format: format,
            reveal: reveal,
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  _MiniLinePainter({
    required this.values,
    required this.color,
    required this.grid,
    required this.labelStyle,
    required this.format,
    required this.reveal,
    required this.textDirection,
  });

  final List<double> values;
  final Color color;
  final Color grid;
  final TextStyle labelStyle;
  final String Function(double) format;
  final double reveal;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final mid = (lo + hi) / 2;

    TextPainter label(double v) => TextPainter(
      text: TextSpan(text: format(v), style: labelStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
    final labels = [label(hi), label(mid), label(lo)];
    final axisWidth =
        labels.map((l) => l.width).reduce((a, b) => a > b ? a : b) + 8;

    const padV = 6.0;
    final left = axisWidth;
    final width = size.width - left;
    if (width <= 0) return;
    final h = size.height - padV * 2;
    double y(double v) => padV + h * (1 - (v - lo) / (hi - lo));
    double x(int i) => left + width * i / (values.length - 1);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final gy = padV + h * i / 2;
      for (var dx = left; dx < size.width; dx += 6) {
        canvas.drawLine(Offset(dx, gy), Offset(dx + 3, gy), gridPaint);
      }
      labels[i].paint(canvas, Offset(0, gy - labels[i].height / 2));
    }

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(left - 4, 0, (width + 8) * reveal, size.height),
    );
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(x(i), y(values[i]));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    // Dots only while sparse enough to read.
    if (values.length <= 12) {
      for (var i = 0; i < values.length; i++) {
        final p = Offset(x(i), y(values[i]));
        canvas.drawCircle(p, 3, Paint()..color = color);
        canvas.drawCircle(p, 1.4, Paint()..color = Colors.white);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MiniLinePainter old) =>
      old.values != values ||
      old.color != color ||
      old.reveal != reveal ||
      old.grid != grid;
}
