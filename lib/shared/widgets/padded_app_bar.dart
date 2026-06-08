import 'package:flutter/material.dart';

abstract final class PaddedAppBar {
  static const topPadding = 22.0;

  static PreferredSizeWidget build(
    BuildContext context, {
    Widget? title,
    Widget? leading,
    List<Widget>? actions,
    bool automaticallyImplyLeading = true,
    double? toolbarHeight,
    bool? centerTitle,
    Color? backgroundColor,
    double? elevation,
    double? scrolledUnderElevation,
    double? leadingWidth,
    PreferredSizeWidget? bottom,
  }) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final barHeight = toolbarHeight ?? kToolbarHeight;
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    final background =
        backgroundColor ?? theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;

    return PreferredSize(
      preferredSize: Size.fromHeight(
        topInset + topPadding + barHeight + bottomHeight,
      ),
      child: ColoredBox(
        color: background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: topInset + topPadding),
            AppBar(
              primary: false,
              clipBehavior: Clip.none,
              automaticallyImplyLeading: automaticallyImplyLeading,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: elevation ?? theme.appBarTheme.elevation ?? 0,
              scrolledUnderElevation:
                  scrolledUnderElevation ?? theme.appBarTheme.scrolledUnderElevation ?? 0,
              toolbarHeight: barHeight,
              leading: leading,
              leadingWidth: leadingWidth,
              title: title,
              actions: actions,
              centerTitle: centerTitle ?? theme.appBarTheme.centerTitle,
              bottom: bottom,
            ),
          ],
        ),
      ),
    );
  }
}
