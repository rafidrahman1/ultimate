import 'dart:ui';

import 'package:flutter/material.dart';

enum GlassNavItem { dashboard }

class GlassBottomNavBar extends StatelessWidget {
  const GlassBottomNavBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final GlassNavItem selected;
  final ValueChanged<GlassNavItem> onSelected;

  static const _items = [
    (
      item: GlassNavItem.dashboard,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      label: 'Dashboard',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: colorScheme.surface.withValues(
                alpha: isDark ? 0.55 : 0.72,
              ),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(
                  alpha: isDark ? 0.45 : 0.65,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final selectedIndex = selected.index;
                  final itemWidth = constraints.maxWidth / _items.length;

                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastOutSlowIn,
                        left: selectedIndex * itemWidth,
                        width: itemWidth,
                        top: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: colorScheme.primary.withValues(alpha: 0.14),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (final entry in _items)
                            Expanded(
                              child: _GlassNavDestination(
                                icon: entry.icon,
                                selectedIcon: entry.selectedIcon,
                                label: entry.label,
                                selected: selected == entry.item,
                                onTap: () => onSelected(entry.item),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavDestination extends StatefulWidget {
  const _GlassNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_GlassNavDestination> createState() => _GlassNavDestinationState();
}

class _GlassNavDestinationState extends State<_GlassNavDestination>
    with TickerProviderStateMixin {
  static const _stateDuration = Duration(milliseconds: 300);

  late final AnimationController _stateController;
  late final Animation<double> _stateProgress;
  late final AnimationController _bounceController;
  late final Animation<double> _bounceScale;

  @override
  void initState() {
    super.initState();
    _stateController = AnimationController(
      vsync: this,
      duration: _stateDuration,
      value: widget.selected ? 1 : 0,
    );
    _stateProgress = CurvedAnimation(
      parent: _stateController,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn,
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.24,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 32,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.24,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 68,
      ),
    ]).animate(_bounceController);
  }

  @override
  void didUpdateWidget(covariant _GlassNavDestination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected) return;

    if (widget.selected) {
      _stateController.forward();
      _bounceController.forward(from: 0);
    } else {
      _stateController.reverse();
    }
  }

  @override
  void dispose() {
    _stateController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: AnimatedBuilder(
          animation: Listenable.merge([_stateProgress, _bounceScale]),
          builder: (context, child) {
            final t = _stateProgress.value;
            final bounce = widget.selected ? _bounceScale.value : 1.0;
            final iconSize = lerpDouble(22, 24, t)!;
            final iconColor = Color.lerp(
              colorScheme.onSurfaceVariant,
              colorScheme.primary,
              t,
            )!;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: bounce,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 1 - t,
                          child: Icon(
                            widget.icon,
                            size: iconSize,
                            color: iconColor,
                          ),
                        ),
                        Opacity(
                          opacity: t,
                          child: Icon(
                            widget.selectedIcon,
                            size: iconSize,
                            color: iconColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall!.copyWith(
                    fontWeight: FontWeight.lerp(
                      FontWeight.w500,
                      FontWeight.w700,
                      t,
                    ),
                    color: iconColor,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
