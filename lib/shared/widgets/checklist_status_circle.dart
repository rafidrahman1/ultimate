import 'package:flutter/material.dart';

import 'package:personal/features/results/insight_checklist_service.dart';
import 'package:personal/shared/widgets/animated_check_circle.dart';

/// Checklist row status indicator: empty circle, check, or failed X.
class ChecklistStatusCircle extends StatelessWidget {
  const ChecklistStatusCircle({
    super.key,
    required this.status,
    required this.color,
    this.size = 26,
  });

  final ChecklistItemStatus status;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (status == ChecklistItemStatus.completed) {
      return AnimatedCheckCircle(checked: true, color: color, size: size);
    }

    if (status == ChecklistItemStatus.failed) {
      return SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.error,
            border: Border.all(
              color: Theme.of(context).colorScheme.error,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.close_rounded,
            size: size * 0.62,
            color: Theme.of(context).colorScheme.onError,
          ),
        ),
      );
    }

    return AnimatedCheckCircle(checked: false, color: color, size: size);
  }
}
