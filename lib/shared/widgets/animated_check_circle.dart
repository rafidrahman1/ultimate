import 'package:flutter/material.dart';

/// Circular checkbox with a fill animation, then an animated checkmark stroke.
class AnimatedCheckCircle extends StatefulWidget {
  const AnimatedCheckCircle({
    super.key,
    required this.checked,
    required this.color,
    this.size = 26,
  });

  final bool checked;
  final Color color;
  final double size;

  @override
  State<AnimatedCheckCircle> createState() => _AnimatedCheckCircleState();
}

class _AnimatedCheckCircleState extends State<AnimatedCheckCircle>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 460);

  late final AnimationController _controller;
  late final Animation<double> _fill;
  late final Animation<double> _ring;
  late final Animation<double> _tick;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _fill = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.52, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    _ring = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.45, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
    _tick = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 1, curve: Curves.easeOutBack),
      reverseCurve: const Interval(0, 0.55, curve: Curves.easeIn),
    );
    if (widget.checked) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(AnimatedCheckCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checked != oldWidget.checked) {
      if (widget.checked) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (_ring.value > 0 && _ring.value < 1)
                Transform.scale(
                  scale: 1 + _ring.value * 0.42,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.color.withValues(
                          alpha: (1 - _ring.value) * 0.55,
                        ),
                        width: 2,
                      ),
                    ),
                    child: SizedBox(width: size, height: size),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.color, width: 2),
                ),
                child: ClipOval(
                  child: Align(
                    alignment: Alignment.center,
                    heightFactor: _fill.value,
                    widthFactor: _fill.value,
                    child: ColoredBox(
                      color: widget.color,
                      child: SizedBox(width: size, height: size),
                    ),
                  ),
                ),
              ),
              if (_tick.value < 1)
                CustomPaint(
                  size: Size(size * 0.58, size * 0.58),
                  painter: _CheckmarkPainter(
                    progress: 1,
                    color: widget.color.withValues(
                      alpha: (1 - _tick.value) * 0.28,
                    ),
                    strokeWidth: size * 0.09,
                  ),
                ),
              if (_tick.value > 0)
                CustomPaint(
                  size: Size(size * 0.58, size * 0.58),
                  painter: _CheckmarkPainter(
                    progress: _tick.value,
                    color: Colors.white,
                    strokeWidth: size * 0.11,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  const _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.14, size.height * 0.54)
      ..lineTo(size.width * 0.4, size.height * 0.8)
      ..lineTo(size.width * 0.88, size.height * 0.24);

    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
