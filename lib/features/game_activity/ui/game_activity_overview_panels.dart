part of 'game_activity_screen.dart';

/// Games ranked by play time with a share bar.
class PlayTimeByGame extends StatelessWidget {
  const PlayTimeByGame({
    super.key,
    required this.games,
    required this.total,
    this.limit,
  });

  final List<MapEntry<String, Duration>> games;
  final Duration total;

  /// Null shows every game.
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.gameActivity(context);
    final shown = limit == null ? games : games.take(limit!).toList();

    return CategoryPanel(
      title: 'Play time by game',
      trailing: 'Total: ${_formatDuration(total, compact: true)}',
      child: Column(
        children: [
          for (final g in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Semantics(
                label:
                    '${g.key}, ${_formatDuration(g.value, compact: true)}, '
                    '${total.inSeconds > 0 ? (g.value.inSeconds / total.inSeconds * 100).round() : 0} percent',
                excludeSemantics: true,
                child: Row(
                  children: [
                    GameAvatar(name: g.key, size: 48),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  g.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 110,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _formatDuration(g.value, compact: true),
                                    maxLines: 1,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                  child: LinearProgressIndicator(
                                    value: total.inSeconds > 0
                                        ? (g.value.inSeconds / total.inSeconds)
                                              .clamp(0.0, 1.0)
                                        : 0,
                                    minHeight: 7,
                                    color: accent,
                                    backgroundColor: palette.border,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 36),
                                child: Text(
                                  total.inSeconds > 0
                                      ? '${(g.value.inSeconds / total.inSeconds * 100).round()}%'
                                      : '',
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: palette.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Weekday grid for the month so far: filled squares are days with play.
class PlayDaysGrid extends StatelessWidget {
  const PlayDaysGrid({super.key, required this.days, required this.monthStart});

  /// One entry per day of the month so far.
  final List<DayBarDatum> days;
  final DateTime monthStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.gameActivity(context);
    final played = days.where((d) => d.value > 0).length;
    final percent = days.isEmpty ? 0 : (played / days.length * 100).round();
    // Monday-first column of day 1.
    final offset = (monthStart.weekday - 1) % 7;
    final cells = offset + days.length;
    final rows = (cells / 7).ceil();
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return CategoryPanel(
      title: 'Play days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final w in weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  for (var c = 0; c < 7; c++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Builder(
                            builder: (context) {
                              final i = r * 7 + c - offset;
                              if (i < 0 || i >= days.length) {
                                return const SizedBox.shrink();
                              }
                              final on = days[i].value > 0;
                              return Semantics(
                                label:
                                    '${DateFormat('MMM d').format(days[i].date)}: '
                                    '${on ? 'played' : 'no play'}',
                                excludeSemantics: true,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: on ? accent : palette.cardElevated,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.small,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$played of ${days.length} days played',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '$percent%',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Most active day and preferred time of day, as two rows.
class PlayHighlights extends StatelessWidget {
  const PlayHighlights({super.key, required this.rows});

  final List<({IconData icon, String label, String value, String caption})>
  rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.gameActivity(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: AppSpacing.xl, color: palette.border),
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: AppOpacity.strong),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Icon(rows[i].icon, color: accent),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rows[i].label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      Text(
                        rows[i].value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        rows[i].caption,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The latest sessions with game tile, time range and duration.
class RecentSessions extends StatelessWidget {
  const RecentSessions({
    super.key,
    required this.sessions,
    required this.onSeeAll,
  });

  final List<GameActivitySession> sessions;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.gameActivity(context);
    final clock = DateFormat('h:mm a');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('RECENT SESSIONS', style: context.sectionLabel),
            ),
            TextButton.icon(
              onPressed: onSeeAll,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('See all'),
            ),
          ],
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < sessions.length; i++) ...[
                if (i > 0) Divider(height: 1, color: palette.border),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      GameAvatar(name: sessions[i].name, size: 52),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sessions[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${DateFormat('EEE, MMM d').format(sessions[i].sessionDate)} · '
                              '${clock.format(sessions[i].sessionDate)} – '
                              '${clock.format(sessions[i].sessionDate.add(sessions[i].timePlayed))}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 90),
                        child: Text(
                          _formatDuration(sessions[i].timePlayed),
                          maxLines: 2,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
