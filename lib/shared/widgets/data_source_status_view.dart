import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';

/// Every condition a data source can be in. One vocabulary for Home cards,
/// dashboard sections and detail screens.
enum DataSourceState {
  unconfigured,
  permissionRequired,
  loading,
  available,
  empty,
  stale,
  error;

  bool get needsAttention => switch (this) {
    unconfigured || permissionRequired || error || stale => true,
    _ => false,
  };

  IconData get icon => switch (this) {
    unconfigured => Icons.add_circle_outline_rounded,
    permissionRequired => Icons.lock_outline_rounded,
    loading => Icons.hourglass_empty_rounded,
    available => Icons.check_circle_outline_rounded,
    empty => Icons.inbox_outlined,
    stale => Icons.history_rounded,
    error => Icons.error_outline_rounded,
  };

  String get defaultTitle => switch (this) {
    unconfigured => 'Not set up',
    permissionRequired => 'Permission needed',
    loading => 'Loading',
    available => 'Up to date',
    empty => 'Nothing for this month',
    stale => 'Data may be out of date',
    error => 'Something went wrong',
  };
}

/// Explains a [DataSourceState] and offers the one action that fixes it.
/// Neutral for setup/empty states; amber for stale; red only for errors.
class DataSourceStatusView extends StatelessWidget {
  const DataSourceStatusView({
    super.key,
    required this.state,
    required this.accent,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final DataSourceState state;

  /// The source's category colour, used for icon and action.
  final Color accent;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Single-row layout for use inside cards.
  final bool compact;

  Color _tone(BuildContext context) {
    final palette = context.palette;
    return switch (state) {
      DataSourceState.error => palette.statusCritical,
      DataSourceState.stale => palette.warning,
      DataSourceState.permissionRequired ||
      DataSourceState.unconfigured => accent,
      _ => palette.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final tone = _tone(context);
    final heading = title ?? state.defaultTitle;

    if (state == DataSourceState.loading) {
      return Semantics(
        label: heading,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBar(width: 72, height: 18),
            const SizedBox(height: AppSpacing.sm),
            SkeletonBar(width: compact ? 96 : 160, height: 10),
          ],
        ),
      );
    }

    final action = actionLabel == null || onAction == null
        ? null
        : TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: tone,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel!),
          );

    if (compact) {
      return Row(
        children: [
          Icon(state.icon, size: 16, color: tone),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message ?? heading,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(state.icon, size: 28, color: tone),
          const SizedBox(height: AppSpacing.sm),
          Text(
            heading,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.sm),
            action,
          ],
        ],
      ),
    );
  }
}

/// Neutral placeholder block shown only while no cached value exists.
class SkeletonBar extends StatelessWidget {
  const SkeletonBar({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.palette.border,
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}
