import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:personal/core/theme/app_theme.dart';

/// One day's value in a [DayBars] chart.
class DayBarDatum {
  const DayBarDatum(this.date, this.value);

  final DateTime date;
  final double value;
}

/// Per-day columns across a month. Tap or drag to read a day; the readout
/// above the chart shows the selected day, or the month average otherwise.
class DayBars extends StatefulWidget {
  const DayBars({
    super.key,
    required this.data,
    required this.color,
    required this.format,
    this.height = 120,
    this.target,
    this.targetLabel,
    this.emptyLabel = 'Nothing recorded',
  });

  /// Consecutive days, oldest first; days without data have value 0.
  final List<DayBarDatum> data;
  final Color color;

  /// Formats a value for the readout, e.g. `(v) => '${v.toStringAsFixed(1)} h'`.
  final String Function(double value) format;
  final double height;

  /// Optional goal line, drawn dashed in the warning colour.
  final double? target;
  final String? targetLabel;
  final String emptyLabel;

  @override
  State<DayBars> createState() => _DayBarsState();
}

class _DayBarsState extends State<DayBars> {
  int? _selected;

  List<DayBarDatum> get _data => widget.data;

  double get _average {
    final active = _data.where((d) => d.value > 0).toList();
    if (active.isEmpty) return 0;
    return active.fold<double>(0, (sum, d) => sum + d.value) / active.length;
  }

  void _select(Offset local, double width) {
    if (_data.isEmpty) return;
    final slot = width / _data.length;
    final index = (local.dx / slot).floor().clamp(0, _data.length - 1);
    if (index == _selected) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = index);
  }

  @override
  void didUpdateWidget(DayBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null && _selected! >= _data.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final data = _data;
    final hasAny = data.any((d) => d.value > 0);
    if (data.isEmpty || !hasAny) {
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

    final selected = _selected == null ? null : data[_selected!];
    final peak = data.reduce((a, b) => a.value >= b.value ? a : b);
    final readoutLabel = selected == null
        ? 'Average per active day'
        : DateFormat('EEE d MMM').format(selected.date);
    final readoutValue = widget.format(
      selected == null ? _average : selected.value,
    );
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 650);

    return Semantics(
      container: true,
      label:
          'Daily chart, ${data.length} days. Average ${widget.format(_average)}. '
          'Peak ${widget.format(peak.value)} on '
          '${DateFormat('d MMMM').format(peak.date)}.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  readoutLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.textMuted,
                  ),
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
                    painter: _DayBarsPainter(
                      data: data,
                      color: widget.color,
                      reveal: reveal,
                      selected: _selected,
                      target: widget.target,
                      average: _average,
                      track: palette.border,
                      muted: palette.textMuted,
                      warning: palette.warning,
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.target != null && widget.targetLabel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Container(width: 14, height: 2, color: palette.warning),
                const SizedBox(width: 6),
                Text(
                  widget.targetLabel!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DayBarsPainter extends CustomPainter {
  _DayBarsPainter({
    required this.data,
    required this.color,
    required this.reveal,
    required this.selected,
    required this.target,
    required this.average,
    required this.track,
    required this.muted,
    required this.warning,
  });

  final List<DayBarDatum> data;
  final Color color;
  final double reveal;
  final int? selected;
  final double? target;
  final double average;
  final Color track;
  final Color muted;
  final Color warning;

  static const _axisHeight = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - _axisHeight;
    final slot = size.width / data.length;
    final barWidth = math.max(2.0, slot * 0.62);
    final maxValue = math.max(
      data.map((d) => d.value).reduce(math.max),
      target ?? 0,
    );
    if (maxValue <= 0) return;

    double yFor(double v) => chartHeight - chartHeight * (v / maxValue);

    // Baseline.
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      Paint()
        ..color = track
        ..strokeWidth = 1,
    );

    for (var i = 0; i < data.length; i++) {
      final value = data[i].value;
      final x = slot * i + (slot - barWidth) / 2;
      final isSelected = selected == i;
      final dim = selected != null && !isSelected;
      if (value <= 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, chartHeight - 2, barWidth, 2),
            const Radius.circular(1),
          ),
          Paint()..color = track,
        );
        continue;
      }
      final h = math.max(3.0, (chartHeight - yFor(value)) * reveal);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, chartHeight - h, barWidth, h),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = color.withValues(alpha: dim ? 0.35 : 1),
      );
    }

    void dashed(double y, Color c) {
      final paint = Paint()
        ..color = c.withValues(alpha: 0.75)
        ..strokeWidth = 1.5;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, size.width), y),
          paint,
        );
      }
    }

    if (target != null) dashed(yFor(target!), warning);
    if (average > 0 && data.where((d) => d.value > 0).length >= 3) {
      dashed(yFor(average), muted);
    }

    // Day numbers under the first, middle and last bars, plus the selection.
    final labelled = {0, data.length ~/ 2, data.length - 1, ?selected};
    for (final i in labelled) {
      final tp = TextPainter(
        text: TextSpan(
          text: '${data[i].date.day}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: selected == i ? FontWeight.w800 : FontWeight.w600,
            color: selected == i ? color : muted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = slot * i + slot / 2;
      final dx = (cx - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _DayBarsPainter old) =>
      old.reveal != reveal ||
      old.selected != selected ||
      old.data != data ||
      old.color != color ||
      old.target != target;
}

/// Buckets [entries] into one [DayBarDatum] per day of [monthStart]'s month
/// (up to today while the month is current).
List<DayBarDatum> buildDayBars(
  Iterable<({DateTime date, double value})> entries,
  DateTime monthStart,
) {
  final now = DateTime.now();
  final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
  final isCurrent =
      now.year == monthStart.year && now.month == monthStart.month;
  final days = isCurrent ? now.day : daysInMonth;

  final totals = List<double>.filled(days, 0);
  for (final entry in entries) {
    final date = entry.date;
    if (date.year != monthStart.year || date.month != monthStart.month) {
      continue;
    }
    if (date.day > days) continue;
    totals[date.day - 1] += entry.value;
  }
  return [
    for (var i = 0; i < days; i++)
      DayBarDatum(
        DateTime(monthStart.year, monthStart.month, i + 1),
        totals[i],
      ),
  ];
}
