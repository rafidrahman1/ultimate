import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';

/// Rounded pill row of tabs; the selected one is tinted with [accent].
/// Labels shrink rather than wrap, so it fits any width or text scale.
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    required this.accent,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final animate = !MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  label: labels[i],
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    onTap: () => onSelected(i),
                    child: AnimatedContainer(
                      duration: animate
                          ? const Duration(milliseconds: 180)
                          : Duration.zero,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == selected
                            ? accent.withValues(alpha: 0.28)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: i == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == selected
                                ? palette.textPrimary
                                : palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
