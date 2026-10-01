import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';

class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.label,
    required this.onPressed,
    required this.color,
    required this.icon,
    this.stat,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData icon;

  /// Headline number for the analysis month; null when no data is loaded.
  final String? stat;

  static const _borderRadius = BorderRadius.all(
    Radius.circular(AppRadii.cardLarge),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final hasData = stat != null;

    return Semantics(
      button: true,
      label: '$label, ${stat ?? 'no data yet'}',
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
                      if (hasData) _LoadedBadge(color: color),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stat ?? 'No data yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hasData ? palette.textPrimary : palette.textMuted,
                      fontWeight: hasData ? FontWeight.w600 : FontWeight.w400,
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

class _LoadedBadge extends StatelessWidget {
  const _LoadedBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    // Pastel accents (dark theme) need a dark tick; deep accents a white one.
    final tickColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(Icons.check, size: 12, color: tickColor),
      ),
    );
  }
}
