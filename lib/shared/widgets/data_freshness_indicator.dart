import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:personal/core/formatting.dart';
import 'package:personal/core/theme/app_theme.dart';

/// Small "Updated 2 h ago" line with a status dot. Turns amber once the data
/// is older than [staleAfter], and shows a thin spinner while [refreshing]
/// (the cached value stays on screen).
class DataFreshnessIndicator extends StatelessWidget {
  const DataFreshnessIndicator({
    super.key,
    required this.updatedAt,
    this.refreshing = false,
    this.staleAfter = const Duration(hours: 24),
    this.prefix = 'Updated',
  });

  final DateTime? updatedAt;
  final bool refreshing;
  final Duration staleAfter;
  final String prefix;

  bool get isStale =>
      updatedAt != null && clock.now().difference(updatedAt!) > staleAfter;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = Theme.of(context).textTheme.labelSmall;
    final stale = isStale;
    final color = stale ? palette.warning : palette.textMuted;
    final text = refreshing
        ? 'Refreshing…'
        : updatedAt == null
        ? 'Not refreshed yet'
        : '$prefix ${relativeTime(updatedAt!)}';

    return Semantics(
      label: stale ? '$text, data may be out of date' : text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (refreshing)
            SizedBox.square(
              dimension: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: palette.textMuted,
              ),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                color: updatedAt == null
                    ? palette.border
                    : stale
                    ? palette.warning
                    : palette.statusGood,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 6),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              stale ? 'Stale · $text' : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
