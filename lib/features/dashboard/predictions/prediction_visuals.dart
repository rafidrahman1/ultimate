import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/predictions/prediction_cards.dart';

/// The small illustration on the right of a prediction card, chosen by
/// [PredictionCardData.visual]. Decorative; the card text carries the meaning.
class PredictionVisualView extends StatelessWidget {
  const PredictionVisualView({super.key, required this.data, this.size = 56});

  final PredictionCardData data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = data.accent;
    final child = switch (data.visual) {
      PredictionVisual.gauge when data.visualValue != null => _GaugeArc(
        value: data.visualValue!,
        color: color,
        size: size,
      ),
      PredictionVisual.dateBadge when data.date != null => _DateBadge(
        date: data.date!,
        color: color,
        size: size,
      ),
      PredictionVisual.car => _CarOnRoad(color: color, size: size),
      PredictionVisual.calendarCheck => _CalendarCheck(
        color: color,
        size: size,
      ),
      _ => null,
    };
    return child == null
        ? const SizedBox.shrink()
        : ExcludeSemantics(child: child);
  }
}

class _GaugeArc extends StatelessWidget {
  const _GaugeArc({
    required this.value,
    required this.color,
    required this.size,
  });

  final double value;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final track = context.palette.border;
    return SizedBox(
      width: size,
      height: size * 0.78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size * 0.78),
            painter: _GaugePainter(value: value, color: color, track: track),
          ),
          Padding(
            padding: EdgeInsets.only(top: size * 0.18),
            child: Icon(
              Icons.local_gas_station_rounded,
              size: size * 0.34,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.color,
    required this.track,
  });

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.width - stroke,
    );
    const start = math.pi * 0.85;
    const sweep = math.pi * 1.3;
    Paint paint(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = c;
    canvas.drawArc(rect, start, sweep, false, paint(track));
    canvas.drawArc(
      rect,
      start,
      sweep * value.clamp(0.0, 1.0),
      false,
      paint(color),
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.color != color || old.track != track;
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({
    required this.date,
    required this.color,
    required this.size,
  });

  final DateTime date;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Container(
      width: size,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: palette.cardElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('MMM').format(date),
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
            Text(
              '${date.day}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarOnRoad extends StatelessWidget {
  const _CarOnRoad({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: size,
      height: size * 0.8,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CustomPaint(
            size: Size(size, size * 0.4),
            painter: _RoadPainter(palette.cardElevated, palette.border),
          ),
          Positioned(
            top: 0,
            child: Icon(
              Icons.directions_car_filled_rounded,
              size: size * 0.6,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.fill, this.line);

  final Color fill;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.3, 0)
      ..lineTo(size.width * 0.7, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawLine(
      Offset(size.width / 2, 2),
      Offset(size.width / 2, size.height),
      Paint()
        ..color = line
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.fill != fill || old.line != line;
}

class _CalendarCheck extends StatelessWidget {
  const _CalendarCheck({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.strong),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: SizedBox.square(
        dimension: size * 0.85,
        child: Icon(
          Icons.event_available_rounded,
          size: size * 0.5,
          color: color,
        ),
      ),
    );
  }
}
