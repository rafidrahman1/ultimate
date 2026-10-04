import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/shared/widgets/sparkline.dart';

class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.label,
    required this.onPressed,
    required this.color,
    required this.icon,
    this.stat,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData icon;

  /// Headline number for the analysis month; null when no data is loaded.
  final HomeTileStat? stat;

  /// True while the source is still being read, so the tile doesn't claim
  /// "no data" prematurely.
  final bool loading;

  static const _borderRadius = BorderRadius.all(
    Radius.circular(AppRadii.cardLarge),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final hasData = stat != null;

    final spoken = loading ? 'loading' : (stat?.spoken ?? 'no data yet');

    return Semantics(
      button: true,
      label: '$label, $spoken',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: _borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: _borderRadius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: _borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: AppOpacity.medium),
                  color.withValues(alpha: AppOpacity.subtle),
                ],
              ),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: AppOpacity.strong),
                          borderRadius: BorderRadius.circular(AppRadii.small),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(icon, size: 20, color: color),
                        ),
                      ),
                      const Spacer(),
                      if (stat?.series case final series?)
                        Sparkline(values: series, color: color)
                      else if (hasData)
                        _LoadedDot(color: color),
                    ],
                  ),
                  const Spacer(),
                  if (loading)
                    const _ValueSkeleton()
                  else
                    Text(
                      stat?.value ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.statDisplay.copyWith(
                        fontSize: 22,
                        color: hasData
                            ? palette.textPrimary
                            : palette.textMuted,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    loading ? 'Loading…' : (stat?.caption ?? 'No data yet'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueSkeleton extends StatelessWidget {
  const _ValueSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.palette.border,
          borderRadius: BorderRadius.circular(AppRadii.xs),
        ),
        child: const SizedBox(width: 56, height: 18),
      ),
    );
  }
}

class _LoadedDot extends StatelessWidget {
  const _LoadedDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
        ],
      ),
      child: const SizedBox.square(dimension: 8),
    );
  }
}
