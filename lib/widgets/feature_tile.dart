import 'dart:ui';

import 'package:flutter/material.dart';

class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.label,
    required this.onPressed,
    required this.color,
    this.dataLoaded = false,
    this.backgroundAsset,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool dataLoaded;
  final String? backgroundAsset;

  static const _borderRadius = BorderRadius.all(Radius.circular(16));
  static const _imageZoom = 1.35;

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
            color: hasBackground ? null : color.withValues(alpha: 0.1),
            border: Border.all(
              color: Colors.white,
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
                    child: Image.asset(
                      backgroundAsset!,
                      fit: BoxFit.cover,
                    ),
                  ),
                // if (hasBackground)
                //   BackdropFilter(
                //     filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                //     child: DecoratedBox(
                //       decoration: BoxDecoration(
                //         gradient: LinearGradient(
                //           begin: Alignment.topLeft,
                //           end: Alignment.bottomRight,
                //           colors: [
                //             Colors.white.withValues(alpha: 0.28),
                //             Colors.white.withValues(alpha: 0.08),
                //           ],
                //         ),
                        
                //       ),
                //     ),
                //   ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: hasBackground ? Colors.white : color,
                            shadows: hasBackground
                                ? const [
                                    Shadow(
                                      blurRadius: 8,
                                      color: Colors.black26,
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
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.check,
                                size: 16,
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
