import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_mode_controller.dart';
import 'circular_app_bar_button.dart';
import 'padded_app_bar.dart';

class AppBarCircularAction {
  const AppBarCircularAction({
    required this.icon,
    this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;
}

abstract final class AppScreenAppBar {
  static PreferredSizeWidget build(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    VoidCallback? onMenuPressed,
    bool showBack = false,
    bool showThemeToggle = false,
    List<AppBarCircularAction> extraActions = const [],
  }) {
    final theme = Theme.of(context);
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
    final useBack = showBack ||
        (onMenuPressed == null && Navigator.canPop(context));

    Widget? leading;
    if (onMenuPressed != null) {
      leading = Padding(
        padding: const EdgeInsets.only(left: 12),
        child: CircularAppBarButton(
          icon: Icons.menu,
          onPressed: onMenuPressed,
        ),
      );
    } else if (useBack) {
      leading = Padding(
        padding: const EdgeInsets.only(left: 12),
        child: CircularAppBarButton(
          icon: Icons.arrow_back,
          onPressed: () => Navigator.maybePop(context),
        ),
      );
    }

    return PaddedAppBar.build(
      context,
      automaticallyImplyLeading: false,
      leadingWidth: leading != null ? 64 : null,
      leading: leading,
      title: Text(
        title,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        for (var i = 0; i < extraActions.length; i++)
          Padding(
            padding: EdgeInsets.only(
              right: i == extraActions.length - 1 && !showThemeToggle ? 12 : 8,
            ),
            child: CircularAppBarButton(
              icon: extraActions[i].icon,
              onPressed: extraActions[i].onPressed,
            ),
          ),
        if (showThemeToggle)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircularAppBarButton(
              icon: isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            ),
          ),
      ],
    );
  }
}
