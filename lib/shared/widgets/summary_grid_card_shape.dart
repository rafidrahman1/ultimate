import 'package:flutter/material.dart';

/// Card outline for summary grid tiles (metric + prompt).
RoundedRectangleBorder summaryGridCardShape(
  BuildContext context, {
  double radius = 12,
  Color? borderColor,
  double borderWidth = 1,
}) {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
    side: BorderSide(
      color: borderColor ?? Theme.of(context).colorScheme.outlineVariant,
      width: borderWidth,
    ),
  );
}
