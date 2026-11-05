import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_theme.dart';

/// Full-width line chart on a faint grid. Drag or tap to move the marker;
/// the footer shows the date on the left and the value on the right, and
/// rests on the latest reading. Oldest point first.
class GridLineChart extends StatefulWidget {
  const GridLineChart({
    super.key,
    required this.points,
    required this.color,
    required this.format,
    this.target,
    this.targetLabel,
    this.height = 130,
    this.dateFormat = 'EEE, d MMM',
  });

  final List<({DateTime date, double value})> points;
  final Color color;
  final String Function(double value) format;

  /// Reference line, e.g. a sleep goal; included in the vertical range.
  final double? target;
  final String? targetLabel;
  final double height;
  final String dateFormat;

  @override
  State<GridLineChart> createState() => _GridLineChartState();
}

class _GridLineChartState extends State<GridLineChart> {
  int? _selected;

  void _select(double dx, double width) {
    final n = widget.points.length;
    if (n < 2 || width <= 0) return;
    final i = (dx / width * (n - 1)).round().clamp(0, n - 1);
    if (i != _selected) setState(() => _selected = i);
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    final theme = Theme.of(context);
    final palette = context.palette;
    if (pts.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'Not enough readings for a trend yet',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ),
      );
    }
    final index = (_selected ?? pts.length - 1).clamp(0, pts.length - 1);
    final selected = pts[index];
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _select(d.localPosition.dx, c.maxWidth),
            onHorizontalDragUpdate: (d) =>
                _select(d.localPosition.dx, c.maxWidth),
            child: Semantics(
              label:
                  'Trend chart, ${pts.length} readings. Selected '
                  '${DateFormat(widget.dateFormat).format(selected.date)}: '
                  '${widget.format(selected.value)}',
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: duration,
                curve: Curves.easeOutCubic,
                builder: (context, reveal, _) => CustomPaint(
                  size: Size(c.maxWidth, widget.height),
                  painter: _GridLinePainter(
                    points: pts,
                    color: widget.color,
                    grid: palette.border,
                    targetColor: palette.textMuted,
                    target: widget.target,
                    selected: index,
                    reveal: reveal,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                DateFormat(widget.dateFormat).format(selected.date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              widget.format(selected.value),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        if (widget.target != null && widget.targetLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Dashed line: ${widget.targetLabel}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _GridLinePainter extends CustomPainter {
  _GridLinePainter({
    required this.points,
    required this.color,
    required this.grid,
    required this.targetColor,
    required this.target,
    required this.selected,
    required this.reveal,
  });

  final List<({DateTime date, double value})> points;
  final Color color;
  final Color grid;
  final Color targetColor;
  final double? target;
  final int selected;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [for (final p in points) p.value, ?target];
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final span = hi - lo;
    lo -= span * 0.08;
    hi += span * 0.08;

    const padV = 8.0;
    final h = size.height - padV * 2;
    double y(double v) => padV + h * (1 - (v - lo) / (hi - lo));
    double x(int i) => size.width * i / (points.length - 1);

    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final gy = padV + h * i / 4;
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gridPaint);
    }
    for (var i = 0; i <= 6; i++) {
      final gx = size.width * i / 6;
      canvas.drawLine(Offset(gx, padV), Offset(gx, padV + h), gridPaint);
    }

    if (target != null) {
      final ty = y(target!);
      final p = Paint()
        ..color = targetColor
        ..strokeWidth = 1;
      for (var dx = 0.0; dx < size.width; dx += 8) {
        canvas.drawLine(Offset(dx, ty), Offset(dx + 4, ty), p);
      }
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(i), y(points[i].value));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    final sel = Offset(x(selected), y(points[selected].value));
    canvas.drawLine(
      Offset(sel.dx, padV),
      Offset(sel.dx, padV + h),
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(sel, 5, Paint()..color = color);
    canvas.drawCircle(sel, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GridLinePainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.reveal != reveal ||
      old.color != color;
}
