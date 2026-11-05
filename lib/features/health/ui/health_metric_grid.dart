import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/mini_line_chart.dart';

/// One card in the Health overview grid.
class HealthMetricCardData {
  const HealthMetricCardData({
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.unit,
    required this.series,
    required this.formatAxis,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String unit;

  /// Oldest first; fewer than two points hides the chart.
  final List<double> series;
  final String Function(double) formatAxis;
  final VoidCallback onTap;
}

/// Two-column grid of metric cards: title, tinted icon pill, big value with a
/// small unit, and a mini line chart. Tapping a card opens its section.
class HealthMetricGrid extends StatelessWidget {
  const HealthMetricGrid({super.key, required this.cards});

  final List<HealthMetricCardData> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var i = 0; i < cards.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _MetricCard(data: cards[i])),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: i + 1 < cards.length
                      ? _MetricCard(data: cards[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final HealthMetricCardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '${data.title}, ${data.value} ${data.unit}. Show details',
      excludeSemantics: true,
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.cardLarge + 8),
          side: BorderSide(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: data.onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: data.color.withValues(alpha: AppOpacity.strong),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Icon(data.icon, size: 16, color: data.color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: data.value,
                        style: context.statDisplay.copyWith(fontSize: 28),
                      ),
                      TextSpan(
                        text: ' ${data.unit}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                MiniLineChart(
                  values: data.series,
                  color: data.color,
                  format: data.formatAxis,
                  height: 72,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
