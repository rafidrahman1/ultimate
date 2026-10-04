import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:personal/core/theme/app_theme.dart';

/// One reading in a [TrendLine]. A null [value] is a day with no reading.
class TrendPoint {
  const TrendPoint(this.date, this.value);

  final DateTime date;
  final double? value;
}

/// A line over time for values that move within a narrow band (resting heart
/// rate, weight), where zero-based bars would look flat. Tap or drag to read a
/// point; with nothing selected the readout shows the average.
class TrendLine extends StatefulWidget {
  const TrendLine({
    super.key,
    required this.data,
    required this.color,
    required this.format,
    this.height = 120,
    this.readoutDateFormat = 'EEE d MMM',
    this.averageLabel = 'Average',
    this.emptyLabel = 'Nothing recorded',
    this.axisLabel,
    this.maxGap = 3,
  });

  /// Readings further apart than this many slots aren't joined by a line.
  /// Raise it for sparse series such as weight.
  final int maxGap;

  /// Oldest first.
  final List<TrendPoint> data;
  final Color color;
  final String Function(double value) format;
  final double height;
  final String readoutDateFormat;
  final String averageLabel;
  final String emptyLabel;
  final String Function(DateTime date)? axisLabel;

  @override
  State<TrendLine> createState() => _TrendLineState();
}

class _TrendLineState extends State<TrendLine> {
  int? _selected;

  List<int> get _present => [
    for (var i = 0; i < widget.data.length; i++)
      if (widget.data[i].value != null) i,
  ];

  double get _average {
    final values = [for (final i in _present) widget.data[i].value!];
    if (values.isEmpty) return 0;
    return values.fold<double>(0, (sum, v) => sum + v) / values.length;
  }

  void _select(Offset local, double width) {
    final present = _present;
    if (present.isEmpty || widget.data.length < 2) return;
    final slot = width / (widget.data.length - 1);
    final target = (local.dx / slot).round().clamp(0, widget.data.length - 1);
    var best = present.first;
    for (final i in present) {
      if ((i - target).abs() < (best - target).abs()) best = i;
    }
    if (best == _selected) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = best);
  }

  @override
  void didUpdateWidget(TrendLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null && _selected! >= widget.data.length) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final present = _present;

    if (present.isEmpty) {
      return SizedBox(
        height: 48,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            widget.emptyLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ),
      );
    }

    final selected = _selected == null ? null : widget.data[_selected!];
    final readoutLabel = selected == null
        ? widget.averageLabel
        : DateFormat(widget.readoutDateFormat).format(selected.date);
    final readoutValue = widget.format(selected?.value ?? _average);
    final values = [for (final i in present) widget.data[i].value!];
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 650);

    return Semantics(
      container: true,
      label:
          'Trend, ${present.length} readings. Average ${widget.format(_average)}, '
          'from ${widget.format(low)} to ${widget.format(high)}.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 2,
            children: [
              Text(
                readoutLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.textMuted,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                child: Text(
                  readoutValue,
                  key: ValueKey(readoutValue),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: widget.color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _select(d.localPosition, width),
                onHorizontalDragUpdate: (d) => _select(d.localPosition, width),
                onTapUp: (_) =>
                    Future<void>.delayed(const Duration(seconds: 3), () {
                      if (mounted) setState(() => _selected = null);
                    }),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  builder: (context, reveal, _) => CustomPaint(
                    size: Size(width, widget.height),
                    painter: _TrendLinePainter(
                      data: widget.data,
                      color: widget.color,
                      reveal: reveal,
                      selected: _selected,
                      average: _average,
                      track: palette.border,
                      muted: palette.textMuted,
                      format: widget.format,
                      axisLabel: widget.axisLabel,
                      maxGap: widget.maxGap,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  _TrendLinePainter({
    required this.data,
    required this.color,
    required this.reveal,
    required this.selected,
    required this.average,
    required this.track,
    required this.muted,
    required this.format,
    required this.axisLabel,
    required this.maxGap,
  });

  final int maxGap;
  final List<TrendPoint> data;
  final Color color;
  final double reveal;
  final int? selected;
  final double average;
  final Color track;
  final Color muted;
  final String Function(double) format;
  final String Function(DateTime)? axisLabel;

  static const _axisHeight = 16.0;
  static const _pad = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final chartHeight = size.height - _axisHeight;
    final values = [
      for (final p in data)
        if (p.value != null) p.value!,
    ];
    if (values.isEmpty) return;

    var low = values.reduce(math.min);
    var high = values.reduce(math.max);
    if (high - low < 1e-9) {
      // A flat series still needs a visible band.
      low -= 1;
      high += 1;
    }
    final margin = (high - low) * 0.12;
    low -= margin;
    high += margin;

    final slot = data.length == 1 ? 0.0 : size.width / (data.length - 1);
    double xFor(int i) => data.length == 1
        ? size.width / 2
        : (slot * i).clamp(_pad, size.width - _pad);
    double yFor(double v) =>
        _pad + (chartHeight - _pad * 2) * (1 - (v - low) / (high - low));

    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      Paint()
        ..color = track
        ..strokeWidth = 1,
    );

    // Average, dashed.
    if (values.length >= 3) {
      final y = yFor(average);
      final dash = Paint()
        ..color = muted.withValues(alpha: 0.6)
        ..strokeWidth = 1.2;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, size.width), y),
          dash,
        );
      }
    }

    // The line, broken across long gaps.
    final line = Paint()
      ..color = color.withValues(alpha: selected == null ? 1 : 0.5)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final revealX = size.width * reveal;
    int? previous;
    for (var i = 0; i < data.length; i++) {
      final v = data[i].value;
      if (v == null) continue;
      final x = xFor(i);
      if (x > revealX) break;
      final y = yFor(v);
      if (previous != null && i - previous <= maxGap) {
        canvas.drawLine(
          Offset(xFor(previous), yFor(data[previous].value!)),
          Offset(x, y),
          line,
        );
      }
      canvas.drawCircle(Offset(x, y), 2.6, Paint()..color = color);
      previous = i;
    }

    final chosen = selected;
    if (chosen != null && data[chosen].value != null) {
      final x = xFor(chosen);
      final y = yFor(data[chosen].value!);
      canvas.drawLine(
        Offset(x, _pad),
        Offset(x, chartHeight),
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = color);
      canvas.drawCircle(
        Offset(x, y),
        2.2,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }

    // Range labels at the left edge.
    void label(String text, double y) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 10,
            color: muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(0, (y - tp.height / 2).clamp(0.0, chartHeight - tp.height)),
      );
    }

    final dataLow = values.reduce(math.min);
    final dataHigh = values.reduce(math.max);
    if (dataHigh - dataLow > 1e-9) {
      label(format(dataHigh), yFor(dataHigh) - 9);
      label(format(dataLow), yFor(dataLow) + 9);
    }

    // First, middle and last dates, plus the selection.
    final labelled = {0, data.length ~/ 2, data.length - 1, ?selected};
    for (final i in labelled) {
      final text = axisLabel?.call(data[i].date) ?? '${data[i].date.day}';
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: selected == i ? FontWeight.w800 : FontWeight.w600,
            color: selected == i ? color : muted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (xFor(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter old) =>
      old.reveal != reveal ||
      old.selected != selected ||
      old.data != data ||
      old.color != color;
}

/// One [TrendPoint] per day of [days], null where there is no reading.
List<TrendPoint> trendPointsFor(
  Iterable<({DateTime date, double? value})> days,
) => [for (final d in days) TrendPoint(d.date, d.value)];
