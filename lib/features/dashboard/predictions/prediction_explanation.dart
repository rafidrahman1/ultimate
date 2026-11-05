import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/predictions/prediction_cards.dart';

Color _confidenceColor(BuildContext context, PredictionConfidence c) {
  final palette = context.palette;
  return switch (c) {
    PredictionConfidence.high => palette.statusGood,
    PredictionConfidence.moderate => palette.warning,
    PredictionConfidence.low => palette.textMuted,
  };
}

/// Quiet three-bar confidence marker with its label.
class PredictionConfidenceIndicator extends StatelessWidget {
  const PredictionConfidenceIndicator({
    super.key,
    required this.confidence,
    this.showLabel = true,
  });

  final PredictionConfidence confidence;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final filled = 3 - confidence.index;
    return Semantics(
      label: '${confidence.label} confidence',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  color: i < filled ? palette.textSecondary : palette.border,
                ),
                child: SizedBox(width: 3, height: 5.0 + i * 2),
              ),
            ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${confidence.label} confidence',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: palette.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tinted pill with signal bars: green High, amber Moderate, grey Low.
/// [compact] drops the word "confidence" for small cards.
class PredictionConfidencePill extends StatelessWidget {
  const PredictionConfidencePill({
    super.key,
    required this.confidence,
    this.compact = false,
  });

  final PredictionConfidence confidence;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _confidenceColor(context, confidence);
    final filled = 3 - confidence.index;
    final label = compact ? confidence.label : '${confidence.label} confidence';
    return Semantics(
      label: '${confidence.label} confidence',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppOpacity.medium),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        color: i < filled
                            ? color
                            : color.withValues(alpha: 0.3),
                      ),
                      child: SizedBox(width: 3, height: 6.0 + i * 3),
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
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

/// Boxed, expandable "Why this estimate?" listing the real inputs and
/// assumptions. Renders nothing when the prediction carries no inputs.
class PredictionExplanation extends StatelessWidget {
  const PredictionExplanation({super.key, required this.data});

  final PredictionCardData data;

  @override
  Widget build(BuildContext context) {
    if (data.facts.isEmpty && data.confidence == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final palette = context.palette;
    final summary =
        data.confidenceReason ??
        data.facts.take(3).map((f) => '${f.label} ${f.value}').join(' · ');

    return Material(
      color: palette.card.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 2,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          leading: Icon(Icons.info_outline_rounded, color: palette.accent),
          title: Text(
            'Why this estimate?',
            style: theme.textTheme.labelLarge?.copyWith(
              color: palette.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: summary.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ),
          children: [
            if (data.confidence != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PredictionConfidenceIndicator(
                    confidence: data.confidence!,
                  ),
                ),
              ),
            for (final f in data.facts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        f.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      f.value,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (data.assumptions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('ASSUMPTIONS', style: context.sectionLabel),
              for (final a in data.assumptions)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $a', style: theme.textTheme.bodySmall),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
