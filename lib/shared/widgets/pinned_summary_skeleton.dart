import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';

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

/// Generic loading placeholder for card-based screens (Dashboard, Results,
/// Checklists): a title line followed by [cardHeights] card blocks.
class CardListSkeleton extends StatefulWidget {
  const CardListSkeleton({
    super.key,
    this.cardHeights = const [140, 220, 180],
    this.bottomPadding = 24,
  });

  final List<double> cardHeights;
  final double bottomPadding;

  @override
  State<CardListSkeleton> createState() => _CardListSkeletonState();
}

class _CardListSkeletonState extends State<CardListSkeleton>
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
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) => _SkeletonScope(
          shimmerValue: _shimmerController.value,
          child: child!,
        ),
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            widget.bottomPadding,
          ),
          children: [
            const SkeletonBox(height: 14, widthFactor: 0.45),
            const SizedBox(height: AppSpacing.sm),
            const SkeletonBox(height: 12, widthFactor: 0.3),
            for (final height in widget.cardHeights) ...[
              const SizedBox(height: AppSpacing.lg),
              SkeletonBox(height: height, borderRadius: AppRadii.cardLarge),
            ],
          ],
        ),
      ),
    );
  }
}
