import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'progress_review_metrics.dart';

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
    final color = _scoreColor(context, score);
    final compact = size <= 56;

    return SizedBox(
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
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: color,
                            height: 1,
                          ),
                    ),
                    Text(
                      '/100',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: palette.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class AdherenceDonut extends StatelessWidget {
  const AdherenceDonut({
    super.key,
    required this.completed,
    required this.total,
    this.percent,
    this.size = 108,
  });

  final int completed;
  final int total;
  final int? percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final progress = total == 0 ? 0.0 : completed / total;
    final pct = percent ?? (progress * 100).round();
    final color = context.palette.accentAlt;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0, 1),
          color: color,
          trackColor: palette.border,
          strokeWidth: 10,
          rounded: true,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '$completed/$total',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DomainRadarChart extends StatelessWidget {
  const DomainRadarChart({super.key, required this.domains});

  final List<DomainScoreMetric> domains;

  @override
  Widget build(BuildContext context) {
    if (domains.isEmpty) return const SizedBox.shrink();

    final palette = context.palette;

    return AspectRatio(
      aspectRatio: 1.15,
      child: CustomPaint(
        painter: _RadarPainter(
          values: [
            for (final domain in domains) (domain.score ?? 0) / 100.0,
          ],
          labels: [for (final domain in domains) _shortLabel(domain.name)],
          colors: [for (final domain in domains) domain.color],
          gridColor: palette.border,
          fillColor: palette.accent.withValues(alpha: 0.18),
          strokeColor: palette.accent,
          labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: palette.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
        ),
      ),
    );
  }
}

class DomainScoreBars extends StatelessWidget {
  const DomainScoreBars({super.key, required this.domains});

  final List<DomainScoreMetric> domains;

  @override
  Widget build(BuildContext context) {
    if (domains.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < domains.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _DomainScoreBar(domain: domains[i]),
        ],
      ],
    );
  }
}

class _DomainScoreBar extends StatelessWidget {
  const _DomainScoreBar({required this.domain});

  final DomainScoreMetric domain;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final score = domain.score ?? 0;
    final color = domain.color;

    return Row(
      children: [
        Icon(domain.icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            _shortLabel(domain.name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  color: palette.border,
                ),
                FractionallySizedBox(
                  widthFactor: (score / 100).clamp(0.05, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.65),
                          color,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 28,
          child: Text(
            '$score',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}

class ComparisonChartCard extends StatelessWidget {
  const ComparisonChartCard({
    super.key,
    required this.metric,
    this.compact = false,
  });

  final DomainComparisonMetric metric;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final maxValue = math.max(metric.actual, metric.target);
    final actualWidth = maxValue == 0 ? 0.0 : metric.actual / maxValue;
    final targetWidth = maxValue == 0 ? 0.0 : metric.target / maxValue;
    final verdictColor = _verdictColor(context, metric.verdict);

    final bars = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ComparisonBar(
          label: 'Actual',
          value: _formatValue(metric.actual, metric.unit),
          widthFactor: actualWidth.clamp(0.04, 1.0),
          color: metric.color,
        ),
        const SizedBox(height: 8),
        _ComparisonBar(
          label: 'Target',
          value: _formatValue(metric.target, metric.unit),
          widthFactor: targetWidth.clamp(0.04, 1.0),
          color: palette.textMuted,
          muted: true,
        ),
      ],
    );

    if (compact) {
      return bars;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: metric.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(metric.icon, color: metric.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      metric.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (metric.verdict != null || metric.score != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (metric.verdict != null)
                  _MiniChip(label: metric.verdict!, color: verdictColor),
                if (metric.score != null)
                  _MiniChip(
                    label: '${metric.score}',
                    color: _scoreColor(context, metric.score!),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          bars,
        ],
      ),
    );
  }
}

String shortVerdictLabel(String? verdict) {
  if (verdict == null || verdict.isEmpty) return '';
  final normalized = verdict.toLowerCase();
  if (normalized.contains('insufficient')) return 'N/A';
  if (normalized.contains('improved')) return 'Up';
  if (normalized.contains('partial')) return 'Partial';
  if (normalized.contains('declined')) return 'Down';
  if (normalized.contains('unchanged')) return 'Flat';
  return verdict.length <= 8 ? verdict : verdict.split(' ').first;
}

class CompactDomainTile extends StatelessWidget {
  const CompactDomainTile({super.key, required this.visual});

  final DomainVisualData visual;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final domain = visual.domain;
    final score = _extractScoreFromDomain(domain.score);
    final color =
        visual.comparison?.color ?? _domainColor(context, domain.name);
    final icon = visual.comparison?.icon ?? Icons.insights_rounded;
    final verdict = domain.verdict;
    final verdictColor = _verdictColor(context, verdict);
    final verdictLabel = shortVerdictLabel(verdict);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _shortLabel(domain.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (score != null)
                ScoreRingChart(score: score, size: 44, stroke: 5),
            ],
          ),
          const Spacer(),
          if (visual.comparison != null)
            _MiniMetricBars(metric: visual.comparison!)
          else if (score != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (score / 100).clamp(0.08, 1.0),
                minHeight: 8,
                backgroundColor: palette.border,
                color: color,
              ),
            ),
          if (verdictLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: verdictColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  verdictLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: verdictColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniMetricBars extends StatelessWidget {
  const _MiniMetricBars({required this.metric});

  final DomainComparisonMetric metric;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxValue = math.max(metric.actual, metric.target);
    final actualFactor =
        maxValue == 0 ? 0.0 : (metric.actual / maxValue).clamp(0.08, 1.0);
    final targetFactor =
        maxValue == 0 ? 0.0 : (metric.target / maxValue).clamp(0.08, 1.0);

    return Column(
      children: [
        _MiniBar(
          factor: actualFactor,
          color: metric.color,
          value: _formatValue(metric.actual, metric.unit),
        ),
        const SizedBox(height: 6),
        _MiniBar(
          factor: targetFactor,
          color: palette.textMuted.withValues(alpha: 0.55),
          value: _formatValue(metric.target, metric.unit),
        ),
      ],
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.factor,
    required this.color,
    required this.value,
  });

  final double factor;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: factor,
              minHeight: 6,
              backgroundColor: context.palette.border,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.palette.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}

int? _extractScoreFromDomain(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'(\d{1,3})\s*/\s*100').firstMatch(raw);
  if (match != null) return int.tryParse(match.group(1)!);
  return int.tryParse(raw.trim());
}

Color _domainColor(BuildContext context, String name) {
  return AppSemanticColors.forDomainName(name, context);
}

class VisualMetricTile extends StatelessWidget {
  const VisualMetricTile({
    super.key,
    required this.metric,
    this.positive = true,
  });

  final VisualBulletMetric metric;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent =
        positive ? AppSemanticColors.expenses(context) : metric.color;

    return Container(
      width: 156,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.12),
            palette.card,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, color: accent, size: 22),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                        height: 1,
                      ),
                ),
              ),
              if (metric.unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  metric.unit,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            metric.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                  height: 1.2,
                ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.label,
    required this.value,
    required this.widthFactor,
    required this.color,
    this.muted = false,
  });

  final String label;
  final String value;
  final double widthFactor;
  final Color color;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: muted ? palette.textMuted : palette.textPrimary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: widthFactor,
            minHeight: 8,
            backgroundColor: palette.border,
            color: muted ? color.withValues(alpha: 0.45) : color,
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
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
    this.rounded = false,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final bool rounded;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = rounded ? StrokeCap.round : StrokeCap.butt;

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

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.values,
    required this.labels,
    required this.colors,
    required this.gridColor,
    required this.fillColor,
    required this.strokeColor,
    this.labelStyle,
  });

  final List<double> values;
  final List<String> labels;
  final List<Color> colors;
  final Color gridColor;
  final Color fillColor;
  final Color strokeColor;
  final TextStyle? labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;
    final sides = values.length;
    final angleStep = (math.pi * 2) / sides;
    final startAngle = -math.pi / 2;

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var ring = 1; ring <= 4; ring++) {
      final ringRadius = radius * (ring / 4);
      final path = Path();
      for (var i = 0; i < sides; i++) {
        final angle = startAngle + angleStep * i;
        final point = Offset(
          center.dx + math.cos(angle) * ringRadius,
          center.dy + math.sin(angle) * ringRadius,
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < sides; i++) {
      final angle = startAngle + angleStep * i;
      final end = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawLine(center, end, gridPaint);
    }

    final dataPath = Path();
    final points = <Offset>[];
    for (var i = 0; i < sides; i++) {
      final angle = startAngle + angleStep * i;
      final valueRadius = radius * values[i].clamp(0, 1);
      final point = Offset(
        center.dx + math.cos(angle) * valueRadius,
        center.dy + math.sin(angle) * valueRadius,
      );
      points.add(point);
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (var i = 0; i < sides; i++) {
      canvas.drawCircle(points[i], 4, Paint()..color = colors[i]);
    }

    if (labelStyle != null) {
      for (var i = 0; i < sides; i++) {
        final angle = startAngle + angleStep * i;
        final labelPoint = Offset(
          center.dx + math.cos(angle) * (radius + 22),
          center.dy + math.sin(angle) * (radius + 22),
        );
        _paintLabel(canvas, labels[i], labelPoint, labelStyle!);
      }
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset center, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}

String _shortLabel(String name) {
  final parts = name.split('&').first.trim();
  if (parts.length <= 10) return parts;
  return parts.split(' ').first;
}

String _formatValue(double value, String unit) {
  final formatted = value >= 1000
      ? value.round().toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          )
      : value % 1 == 0
          ? value.round().toString()
          : value.toStringAsFixed(2);
  return '$formatted $unit';
}

Color _scoreColor(BuildContext context, int score) {
  if (score >= 76) return AppSemanticColors.expenses(context);
  if (score >= 51) return Theme.of(context).colorScheme.tertiary;
  if (score >= 26) return AppSemanticColors.mobility(context);
  return Theme.of(context).colorScheme.error;
}

Color _verdictColor(BuildContext context, String? verdict) {
  final scheme = Theme.of(context).colorScheme;
  final normalized = verdict?.trim().toLowerCase() ?? '';
  if (normalized.contains('improved')) {
    return AppSemanticColors.expenses(context);
  }
  if (normalized.contains('partial')) return scheme.tertiary;
  if (normalized.contains('declined')) return scheme.error;
  if (normalized.contains('unchanged')) return scheme.onSurfaceVariant;
  return scheme.outline;
}
