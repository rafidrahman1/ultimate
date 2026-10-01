import 'package:flutter/material.dart';

import 'package:personal/shared/widgets/pinned_summary_layout.dart';
import 'package:personal/shared/widgets/summary_grid_card_shape.dart';

enum PinnedSummaryListItemStyle { compact, detailed }

/// Skeleton placeholder matching [PinnedSummaryLayout] while data loads.
class PinnedSummarySkeleton extends StatefulWidget {
  const PinnedSummarySkeleton({
    super.key,
    this.metricCount = 2,
    this.includePromptTile = true,
    this.listItemCount = 6,
    this.listItemStyle = PinnedSummaryListItemStyle.compact,
    this.showHeader = true,
    this.showListSectionHeader = false,
    this.reserveFabSpace = true,
  });

  final int metricCount;
  final bool includePromptTile;
  final int listItemCount;
  final PinnedSummaryListItemStyle listItemStyle;
  final bool showHeader;
  final bool showListSectionHeader;
  final bool reserveFabSpace;

  @override
  State<PinnedSummarySkeleton> createState() => _PinnedSummarySkeletonState();
}

class _PinnedSummarySkeletonState extends State<PinnedSummarySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return _SkeletonScope(
          shimmerValue: _shimmerController.value,
          child: child!,
        );
      },
      child: _PinnedSummarySkeletonBody(
        metricCount: widget.metricCount,
        includePromptTile: widget.includePromptTile,
        listItemCount: widget.listItemCount,
        listItemStyle: widget.listItemStyle,
        showHeader: widget.showHeader,
        showListSectionHeader: widget.showListSectionHeader,
        reserveFabSpace: widget.reserveFabSpace,
      ),
    );
  }
}

class _SkeletonScope extends InheritedWidget {
  const _SkeletonScope({required this.shimmerValue, required super.child});

  final double shimmerValue;

  static _SkeletonScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SkeletonScope>();
    assert(scope != null, 'SkeletonBox must be inside PinnedSummarySkeleton');
    return scope!;
  }

  @override
  bool updateShouldNotify(_SkeletonScope oldWidget) {
    return oldWidget.shimmerValue != shimmerValue;
  }
}

class _PinnedSummarySkeletonBody extends StatelessWidget {
  const _PinnedSummarySkeletonBody({
    required this.metricCount,
    required this.includePromptTile,
    required this.listItemCount,
    required this.listItemStyle,
    required this.showHeader,
    required this.showListSectionHeader,
    required this.reserveFabSpace,
  });

  final int metricCount;
  final bool includePromptTile;
  final int listItemCount;
  final PinnedSummaryListItemStyle listItemStyle;
  final bool showHeader;
  final bool showListSectionHeader;
  final bool reserveFabSpace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = PinnedSummaryLayout.listPadding(
      context,
      reserveFabSpace: reserveFabSpace,
    );
    final tileCount = metricCount + (includePromptTile ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHeader) ...[
                const SkeletonBox(height: 14, widthFactor: 0.55),
                const SizedBox(height: 8),
                const SkeletonBox(height: 12, widthFactor: 0.4),
                const SizedBox(height: 12),
              ],
              _SummaryCardSkeleton(tileCount: tileCount),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        Expanded(
          child: ListView(
            padding: padding,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (showListSectionHeader) ...[
                const SkeletonBox(
                  height: 16,
                  widthFactor: 0.35,
                  borderRadius: 6,
                ),
                const SizedBox(height: 4),
                const SkeletonBox(
                  height: 12,
                  widthFactor: 0.45,
                  borderRadius: 6,
                ),
                const SizedBox(height: 8),
              ],
              for (var i = 0; i < listItemCount; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                switch (listItemStyle) {
                  PinnedSummaryListItemStyle.compact =>
                    const _CompactListItemSkeleton(),
                  PinnedSummaryListItemStyle.detailed =>
                    const _DetailedListItemSkeleton(),
                },
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCardSkeleton extends StatelessWidget {
  const _SummaryCardSkeleton({required this.tileCount});

  final int tileCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SkeletonBox(width: 24, height: 24, borderRadius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(
                        height: 14,
                        widthFactor: 0.35,
                        borderRadius: 6,
                      ),
                      const SizedBox(height: 6),
                      SkeletonBox(
                        height: 12,
                        widthFactor: 0.6,
                        borderRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final cellWidth = (constraints.maxWidth - spacing) / 2;
                final rowCount = (tileCount / 2).ceil();
                final cellHeight = cellWidth * 0.88;
                final gridHeight =
                    rowCount * cellHeight + (rowCount - 1) * spacing;

                return SizedBox(
                  height: gridHeight,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: cellWidth / cellHeight,
                    ),
                    itemCount: tileCount,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        clipBehavior: Clip.antiAlias,
                        shape: summaryGridCardShape(context),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SkeletonBox(
                                    width: 32,
                                    height: 32,
                                    borderRadius: 10,
                                  ),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: SkeletonBox(
                                      height: 12,
                                      borderRadius: 6,
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(),
                              SkeletonBox(
                                height: 16,
                                widthFactor: 0.7,
                                borderRadius: 6,
                              ),
                              SizedBox(height: 6),
                              SkeletonBox(
                                height: 10,
                                widthFactor: 0.9,
                                borderRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactListItemSkeleton extends StatelessWidget {
  const _CompactListItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SkeletonBox(width: 40, height: 40, borderRadius: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 14, widthFactor: 0.25, borderRadius: 6),
                  const SizedBox(height: 8),
                  SkeletonBox(height: 12, widthFactor: 0.85, borderRadius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailedListItemSkeleton extends StatelessWidget {
  const _DetailedListItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 14, widthFactor: 0.55, borderRadius: 6),
                  const SizedBox(height: 8),
                  SkeletonBox(height: 12, widthFactor: 0.75, borderRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SkeletonBox(width: 72, height: 16, borderRadius: 6),
          ],
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.widthFactor,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double? widthFactor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmer = _SkeletonScope.of(context).shimmerValue;
    final base = theme.colorScheme.surfaceContainerHighest;
    final highlight = Color.lerp(base, theme.colorScheme.surface, 0.85)!;

    final gradientBegin = Alignment(-1.0 + 2.0 * shimmer, 0);
    final gradientEnd = Alignment(-0.2 + 2.0 * shimmer, 0);

    Widget child = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: gradientBegin,
          end: gradientEnd,
          colors: [base, highlight, base],
        ),
      ),
    );

    if (widthFactor != null) {
      child = FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: child,
      );
    }

    return child;
  }
}
