import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';

/// Checklist control used for the Home app bar action and Results pinning.
class HomeChecklistIcon extends StatelessWidget {
  const HomeChecklistIcon({
    super.key,
    required this.selected,
    this.size = 24,
  });

  final bool selected;
  final double size;

  static IconData iconData({required bool selected}) =>
      selected ? Icons.playlist_add_check : Icons.playlist_add_check_outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Icon(
      iconData(selected: selected),
      size: size,
      color: selected
          ? AppSemanticColors.result(context)
          : theme.colorScheme.onSurfaceVariant,
    );
  }
}
