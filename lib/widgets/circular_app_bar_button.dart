import 'package:flutter/material.dart';

class CircularAppBarButton extends StatelessWidget {
  const CircularAppBarButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  static const size = 48.0;
  static const iconSize = 24.0;

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
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
    );
  }
}
