import 'package:flutter/material.dart';

/// Groups summary metric and prompt cards in an expandable section.
class CollapsibleSummarySection extends StatefulWidget {
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

  @override
  State<CollapsibleSummarySection> createState() =>
      _CollapsibleSummarySectionState();
}

class _CollapsibleSummarySectionState extends State<CollapsibleSummarySection>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 280);

  bool _expanded = false;
  late final AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: _duration,
      value: 0,
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _iconController.forward();
    } else {
      _iconController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.accent ?? theme.colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: accentColor, size: 24),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    RotationTransition(
                      turns: Tween<double>(begin: 0, end: 0.5).animate(
                        CurvedAnimation(
                          parent: _iconController,
                          curve: Curves.easeInOutCubic,
                        ),
                      ),
                      child: Icon(
                        Icons.expand_more,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: _duration,
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _SummaryTileGrid(
                      metrics: widget.metrics,
                      prompt: widget.prompt,
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

class _SummaryTileGrid extends StatelessWidget {
  const _SummaryTileGrid({required this.metrics, this.prompt});

  final List<Widget> metrics;
  final Widget? prompt;

  @override
  Widget build(BuildContext context) {
    final tiles = [...metrics, ?prompt];
    if (tiles.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final cellWidth = (constraints.maxWidth - spacing) / 2;
        final cellHeight = cellWidth * 0.88;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles)
              SizedBox(width: cellWidth, height: cellHeight, child: tile),
          ],
        );
      },
    );
  }
}
