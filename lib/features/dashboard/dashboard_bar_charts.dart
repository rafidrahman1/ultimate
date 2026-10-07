part of 'dashboard_charts.dart';

class DashboardHorizontalBars extends StatelessWidget {
  const DashboardHorizontalBars({
    super.key,
    required this.items,
    required this.color,
    this.emptyLabel = 'No data',
  });

  final List<DashboardBarItem> items;
  final Color color;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        emptyLabel,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.palette.textMuted),
      );
    }

    final maxValue = items
        .map((item) => item.value)
        .fold<double>(0, (max, value) => math.max(max, value));

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _HorizontalBarRow(item: items[i], maxValue: maxValue, color: color),
        ],
      ],
    );
  }
}

class _HorizontalBarRow extends StatelessWidget {
  const _HorizontalBarRow({
    required this.item,
    required this.maxValue,
    required this.color,
  });

  final DashboardBarItem item;
  final double maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final factor = maxValue == 0
        ? 0.0
        : (item.value / maxValue).clamp(0.04, 1.0);

    return Semantics(
      label: '${item.label}: ${item.displayValue}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.displayValue,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: factor),
              duration: _chartDuration(context),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: palette.border,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardColumnChart extends StatelessWidget {
  const DashboardColumnChart({
    super.key,
    required this.items,
    required this.color,
    this.height = 160,
    this.targetLine,
  });

  final List<DashboardBarItem> items;
  final Color color;
  final double height;
  final double? targetLine;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final palette = context.palette;
    final maxValue = items
        .map((item) => item.value)
        .fold<double>(0, (max, value) => math.max(max, value));

    return LayoutBuilder(
      builder: (context, constraints) {
        // Roomy bars with value labels when they fit; otherwise squeeze every
        // bar into the width (no sideways scrolling) and rely on tap-to-read.
        const roomyWidth = 34.0;
        const roomyGap = 8.0;
        final roomyTotal =
            items.length * roomyWidth + (items.length - 1) * roomyGap;
        final compact = roomyTotal > constraints.maxWidth;
        final gap = compact ? 3.0 : roomyGap;
        final barSlot = compact
            ? (constraints.maxWidth - gap * (items.length - 1)) / items.length
            : roomyWidth;
        final labelEvery = compact ? math.max(1, (items.length / 6).ceil()) : 1;

        return SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                _ColumnBar(
                  item: items[i],
                  maxValue: maxValue,
                  color: color,
                  targetLine: targetLine,
                  palette: palette,
                  slotWidth: barSlot,
                  compact: compact,
                  showLabel: i % labelEvery == 0,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ColumnBar extends StatelessWidget {
  const _ColumnBar({
    required this.item,
    required this.maxValue,
    required this.color,
    required this.targetLine,
    required this.palette,
    required this.slotWidth,
    required this.compact,
    required this.showLabel,
  });

  final DashboardBarItem item;
  final double maxValue;
  final Color color;
  final double? targetLine;
  final AppPalette palette;
  final double slotWidth;
  final bool compact;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final factor = maxValue == 0
        ? 0.0
        : (item.value / maxValue).clamp(0.0, 1.0);
    final hasValue = item.value > 0;
    final barColor = hasValue ? color : palette.border;
    final barWidth = compact ? slotWidth : 22.0;

    return Semantics(
      label: '${item.label}: ${item.displayValue}',
      excludeSemantics: true,
      child: SizedBox(
        width: slotWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!compact) ...[
              if (hasValue)
                Text(
                  item.displayValue,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                )
              else
                const SizedBox(height: 12),
              const SizedBox(height: 4),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barHeight = constraints.maxHeight * factor;
                  final targetHeight = targetLine == null || maxValue == 0
                      ? null
                      : constraints.maxHeight *
                            (targetLine! / maxValue).clamp(0.0, 1.0);

                  return Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      if (targetHeight != null)
                        Positioned(
                          bottom: targetHeight,
                          left: compact ? -1.5 : 0,
                          right: compact ? -1.5 : 0,
                          child: Container(
                            height: 1.5,
                            color: palette.warning.withValues(alpha: 0.7),
                          ),
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Tooltip(
                          message: '${item.label}: ${item.displayValue}',
                          triggerMode: TooltipTriggerMode.tap,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: math.max(barHeight, hasValue ? 6 : 4),
                            ),
                            duration: _chartDuration(context),
                            curve: Curves.easeOutCubic,
                            builder: (context, height, _) => Container(
                              width: barWidth,
                              height: height,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(compact ? 2 : 4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 12,
              child: showLabel
                  ? OverflowBox(
                      maxWidth: 40,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
