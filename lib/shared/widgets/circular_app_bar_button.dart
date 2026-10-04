import 'package:flutter/material.dart';

class CircularAppBarButton extends StatelessWidget {
  const CircularAppBarButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  static const size = 48.0;
  static const iconSize = 24.0;

  final IconData icon;
  final VoidCallback? onPressed;

  /// Accessible label; falls back to a name derived from [icon].
  final String? tooltip;

  static final _iconLabels = <IconData, String>{
    Icons.menu: 'Open menu',
    Icons.arrow_back: 'Back',
    Icons.close: 'Close',
    Icons.refresh: 'Refresh',
    Icons.sync: 'Sync',
    Icons.copy_outlined: 'Copy',
    Icons.delete_sweep_outlined: 'Clear',
    Icons.restart_alt: 'Reset',
    Icons.insights_outlined: 'Past reports',
    Icons.swap_horiz_rounded: 'Switch checklist',
    Icons.light_mode_outlined: 'Switch to light theme',
    Icons.dark_mode_outlined: 'Switch to dark theme',
    Icons.auto_awesome_outlined: 'Analyze',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip ?? _iconLabels[icon] ?? '',
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: iconSize,
              color: onPressed == null
                  ? colorScheme.onSurface.withValues(alpha: 0.38)
                  : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
