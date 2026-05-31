import 'package:flutter/material.dart';

import '../features/results/insight_detail_overlay.dart';
import 'summary_grid_card_shape.dart';

/// Prompt block sent to monthly analysis; long-press shows the full text.
class AnalysisPromptPreviewCard extends StatelessWidget {
  const AnalysisPromptPreviewCard({
    super.key,
    required this.promptText,
    required this.detailTitle,
    required this.accent,
    this.icon = Icons.article_outlined,
    this.compact = false,
  });

  final String promptText;
  final String detailTitle;
  final Color accent;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return InsightLongPressCard(
        detailTitle: detailTitle,
        detailBody: promptText,
        accent: accent,
        icon: icon,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: summaryGridCardShape(
            context,
            borderColor: accent.withValues(alpha: 0.4),
          ),
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: accent, size: 18),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Prompt',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Long press to view',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return InsightLongPressCard(
      detailTitle: detailTitle,
      detailBody: promptText,
      accent: accent,
      icon: icon,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: summaryGridCardShape(
          context,
          borderColor: accent.withValues(alpha: 0.4),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Prompt',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Long press to view',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
