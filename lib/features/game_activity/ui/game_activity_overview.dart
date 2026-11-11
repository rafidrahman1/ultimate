part of 'game_activity_screen.dart';

enum GameTab {
  overview('Overview'),
  sessions('Sessions'),
  games('Games'),
  trends('Trends'),
  insights('Insights');

  const GameTab(this.label);
  final String label;
}

/// A game's cover art when enabled and found; otherwise its initial on a
/// tinted tile.
class GameAvatar extends ConsumerWidget {
  const GameAvatar({super.key, required this.name, this.size = 48});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = ref.watch(gameCoverProvider(name)).value;
    if (cover != null) {
      return ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Image.file(
            cover,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * 3).round(),
            errorBuilder: (context, _, _) => SizedBox.square(dimension: size),
          ),
        ),
      );
    }
    final accent = AppSemanticColors.gameActivity(context);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: AppOpacity.strong),
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: Text(
              initial,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Total play time with a cumulative trend line, change against last month's
/// same days, and the four numbers behind it.
class PlayTimeHero extends StatelessWidget {
  const PlayTimeHero({
    super.key,
    required this.total,
    required this.caption,
    required this.series,
    required this.comparison,
    required this.stats,
  });

  final String total;
  final String caption;

  /// Running total of play time per day, oldest first; under two points hides
  /// the line.
  final List<double> series;

  /// Prebuilt change text such as `(text: '+128%', caption: 'vs Oct 1–5',
  /// rising: true)`; null hides the chip.
  final ({String text, String caption, bool rising})? comparison;
  final List<({IconData icon, String value, String label})> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.gameActivity(context);
    final cmp = comparison;

    return AppCard(
      tier: AppCardTier.hero,
      accent: accent,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: AppOpacity.strong),
                  borderRadius: BorderRadius.circular(AppRadii.cardLarge),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.sports_esports_rounded,
                    color: accent,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PLAY TIME', style: context.sectionLabel),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        total,
                        maxLines: 1,
                        style: context.statDisplay.copyWith(
                          fontSize: 36,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      caption,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (series.length >= 2) ...[
                const SizedBox(width: AppSpacing.sm),
                Sparkline(values: series, color: accent, width: 84, height: 52),
              ],
            ],
          ),
          if (cmp != null) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.cardElevated,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: palette.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cmp.rising
                            ? Icons.north_east_rounded
                            : Icons.south_east_rounded,
                        size: 16,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${cmp.text} ',
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: cmp.caption,
                                style: TextStyle(color: palette.textMuted),
                              ),
                            ],
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: palette.border),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 330 &&
                      MediaQuery.textScalerOf(context).scale(1) <= 1.3
                  ? 4
                  : 2;
              const gap = AppSpacing.md;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: AppSpacing.md,
                children: [
                  for (final s in stats)
                    SizedBox(
                      width: width,
                      child: Semantics(
                        label: '${s.value} ${s.label}',
                        excludeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(s.icon, size: 20, color: accent),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                s.value,
                                maxLines: 1,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              s.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: palette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
