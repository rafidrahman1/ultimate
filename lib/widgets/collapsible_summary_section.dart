import 'package:flutter/material.dart';

/// Groups summary metric and prompt cards in an expandable section.
class CollapsibleSummarySection extends StatelessWidget {
  const CollapsibleSummarySection({
    super.key,
    required this.title,
    required this.metrics,
    this.prompt,
    this.subtitle,
    this.icon,
    this.accent,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? accent;
  final List<Widget> metrics;
  final Widget? prompt;

  int get _tileCount => metrics.length + (prompt != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = accent ?? theme.colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: icon != null ? Icon(icon, color: accentColor) : null,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final cellWidth = (constraints.maxWidth - spacing) / 2;
                if (_tileCount == 0) return const SizedBox.shrink();

                final rowCount = (_tileCount / 2).ceil();
                final cellHeight = cellWidth * 0.88;
                final gridHeight =
                    rowCount * cellHeight + (rowCount - 1) * spacing;
                final maxHeight = MediaQuery.sizeOf(context).height * 0.45;

                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: gridHeight,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          mainAxisExtent: cellHeight,
                        ),
                        itemCount: _tileCount,
                        itemBuilder: (context, index) {
                          if (index < metrics.length) {
                            return metrics[index];
                          }
                          return prompt!;
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
