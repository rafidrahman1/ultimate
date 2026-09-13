import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';

class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.label,
    required this.onPressed,
    required this.color,
    required this.icon,
    this.dataLoaded = false,
    this.backgroundAsset,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData icon;
  final bool dataLoaded;
  final String? backgroundAsset;

  static const _borderRadius = BorderRadius.all(Radius.circular(AppRadii.card));
  static const _imageZoom = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBackground = backgroundAsset != null;

    return Material(
      color: Colors.transparent,
      borderRadius: _borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        borderRadius: _borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: _borderRadius,
            gradient: hasBackground
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: AppOpacity.medium),
                      color.withValues(alpha: AppOpacity.subtle),
                    ],
                  ),
            border: Border.all(
              color: hasBackground
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.85,
                    )
                  : theme.colorScheme.outline,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: _borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasBackground)
                  Transform.scale(
                    scale: _imageZoom,
                    child: Image.asset(backgroundAsset!, fit: BoxFit.cover),
                  ),
                if (!hasBackground)
                  Positioned(
                    bottom: -10,
                    right: -10,
                    child: Icon(
                      icon,
                      size: 72,
                      color: color.withValues(alpha: AppOpacity.subtle),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: hasBackground ? Colors.white : color,
                            shadows: hasBackground
                                ? [
                                    Shadow(
                                      blurRadius: 8,
                                      color: theme.colorScheme.shadow
                                          .withValues(alpha: 0.26),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                      if (dataLoaded)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: hasBackground ? Colors.white : color,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                Icons.check,
                                size: 12,
                                color: hasBackground ? color : Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
