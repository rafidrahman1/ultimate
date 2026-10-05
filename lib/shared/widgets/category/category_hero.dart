import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// One labelled figure in a [CategoryHero] footer.
class HeroStat {
  const HeroStat(this.label, this.value);

  final String label;
  final String value;
}

/// The card that leads every data category page: what the page is, the one
/// number that matters, and a few supporting figures.
class CategoryHero extends StatelessWidget {
  const CategoryHero({
    super.key,
    required this.accent,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.footnote,
    this.stats = const [],
    this.visual,
  });

  final Color accent;
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? caption;

  /// Small right-aligned line, e.g. the period or source file.
  final String? footnote;
  final List<HeroStat> stats;

  /// Optional chart shown under the headline number.
  final Widget? visual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final card = AppCard(
      tier: AppCardTier.hero,
      accent: accent,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: AppOpacity.strong),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.sectionLabel.copyWith(color: accent),
                ),
              ),
              if (footnote != null)
                Flexible(
                  child: Text(
                    footnote!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            label: '$label, $value${unit == null ? '' : ' $unit'}',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: context.statDisplay.copyWith(
                        fontSize: 44,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    unit!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: palette.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ],
          if (visual != null) ...[
            const SizedBox(height: AppSpacing.lg),
            visual!,
          ],
          if (stats.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Divider(height: 1, color: accent.withValues(alpha: 0.2)),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xxl,
              runSpacing: AppSpacing.md,
              children: [for (final stat in stats) _HeroStatView(stat: stat)],
            ),
          ],
        ],
      ),
    );

    if (reduceMotion) return card;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - t)),
          child: child,
        ),
      ),
      child: card,
    );
  }
}

class _HeroStatView extends StatelessWidget {
  const _HeroStatView({required this.stat});

  final HeroStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${stat.label}: ${stat.value}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stat.value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            stat.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
