import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/pull_to_refresh.dart';

/// Scroll scaffold shared by the data category pages: pull-to-refresh, a
/// width cap on tablets, standard gutters and room for the floating action
/// button. Compose [slivers] from [categoryBox] and [categoryList].
class CategoryScroll extends StatelessWidget {
  const CategoryScroll({
    super.key,
    required this.slivers,
    this.onRefresh,
    this.reserveFab = true,
  });

  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;
  final bool reserveFab;

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.paddingOf(context).bottom + (reserveFab ? 96.0 : 24.0);
    return PullToRefresh(
      onRefresh: onRefresh,
      child: ContentWidth(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            ...slivers,
            SliverToBoxAdapter(child: SizedBox(height: bottom)),
          ],
        ),
      ),
    );
  }
}

/// A single box in a [CategoryScroll] with the screen gutters applied.
Widget categoryBox(Widget child, {double bottom = AppSpacing.lg}) {
  return SliverPadding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.screen,
      0,
      AppSpacing.screen,
      bottom,
    ),
    sliver: SliverToBoxAdapter(child: child),
  );
}

/// A lazily built list in a [CategoryScroll] with the screen gutters applied.
Widget categoryList({
  required int itemCount,
  required NullableIndexedWidgetBuilder itemBuilder,
  double bottom = AppSpacing.lg,
}) {
  return SliverPadding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.screen,
      0,
      AppSpacing.screen,
      bottom,
    ),
    sliver: SliverList.builder(itemCount: itemCount, itemBuilder: itemBuilder),
  );
}
