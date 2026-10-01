part of 'progress_review_dashboard.dart';

// Circular 0-100 score gauge.

class ScoreRingChart extends StatelessWidget {
  const ScoreRingChart({
    super.key,
    required this.score,
    this.size = 148,
    this.stroke = 14,
  });

  final int score;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = reviewStatusColor(context, reviewStatusFromScore(score));
    final compact = size <= 56;

    return Semantics(
      label: 'Score $score out of 100',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: score / 100,
            color: color,
            trackColor: palette.border,
            strokeWidth: compact ? math.max(4, size * 0.11) : stroke,
          ),
          child: Center(
            child: compact
                ? Text(
                    '$score',
                    style: TextStyle(
                      fontSize: size * 0.3,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: color,
                              height: 1,
                            ),
                      ),
                      Text(
                        '/100',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: palette.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
