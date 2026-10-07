part of 'expense_panels.dart';

/// When the budget runs out and when the next income lands.
class MoneyOutlookPanel extends StatelessWidget {
  const MoneyOutlookPanel({
    super.key,
    required this.money,
    this.budget,
    this.payday,
    this.ai,
    this.onRefineWithAi,
    this.aiBusy = false,
    this.aiError,
  });

  final NumberFormat money;
  final BudgetOutlook? budget;
  final PaydayOutlook? payday;
  final OutlookAiEstimate? ai;
  final VoidCallback? onRefineWithAi;
  final bool aiBusy;
  final String? aiError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.expenses(context);
    final date = DateFormat('d MMM');
    final b = budget;
    final p = payday;

    final budgetHeadline = b == null
        ? null
        : b.isOver
        ? 'Budget used up'
        : b.runoutDate == null
        ? 'Budget lasts the month'
        : 'Budget runs out ${date.format(b.runoutDate!)}';
    final budgetWarn = b != null && (b.isOver || b.runoutDate != null);

    return CategoryPanel(
      title: b != null && p != null
          ? 'Budget and payday'
          : b != null
          ? 'Budget'
          : 'Payday',
      trailing: b == null ? null : '${money.format(b.budget)} budget',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (b != null) ...[
            Text(
              budgetHeadline!,
              style: theme.textTheme.titleMedium?.copyWith(
                color: budgetWarn ? palette.warning : accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              b.isOver
                  ? '${money.format(-b.left)} over so far.'
                  : '${money.format(b.left)} left, on pace to finish at '
                        '${money.format(b.projected)}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
            if (ai != null && ai!.hasBudget)
              _AiLine(
                ai!.budgetRunout == null
                    ? 'AI: budget lasts the month'
                    : 'AI: budget runs out ${date.format(ai!.budgetRunout!)}',
                ai!.budgetNote,
              ),
          ],
          if (b != null && p != null) const SizedBox(height: AppSpacing.md),
          if (p != null) ...[
            Text(
              p.daysUntil < 0
                  ? '${p.label} is ${-p.daysUntil} days late'
                  : p.daysUntil == 0
                  ? '${p.label} due today'
                  : '${p.label} in ${p.daysUntil} days',
              style: theme.textTheme.titleMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${money.format(p.amount)} expected ${date.format(p.expectedDate)}. '
              'Until then a normal pace spends about '
              '${money.format(p.expectedSpend)}'
              '${p.billsBefore > 0 ? ', including ${money.format(p.billsBefore)} of known bills' : ''}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
            if (ai != null && (ai!.payday != null || ai!.paydaySpend != null))
              _AiLine(
                'AI: ${ai!.payday == null ? 'payday' : date.format(ai!.payday!)}'
                '${ai!.paydaySpend == null ? '' : ' · about ${money.format(ai!.paydaySpend!)} spent until then'}',
                ai!.paydayNote,
              ),
          ],
          _RefineFooter(
            refinedAt: _latest(
              b == null ? null : ai?.refinedAt[OutlookSection.budget],
              p == null ? null : ai?.refinedAt[OutlookSection.payday],
            ),
            stale:
                (b != null &&
                    (ai?.isOld(OutlookSection.budget, DateTime.now()) ??
                        false)) ||
                (p != null &&
                    (ai?.isOld(OutlookSection.payday, DateTime.now()) ??
                        false)),
            busy: aiBusy,
            error: aiError,
            onRefine: onRefineWithAi,
            sends: b != null
                ? 'Sends your budget, daily spending for the last 120 days and '
                      'upcoming calendar events to your AI provider.'
                : 'Sends your income entries from the last 12 months, daily '
                      'spending and upcoming calendar events to your AI '
                      'provider.',
          ),
        ],
      ),
    );
  }
}

/// Last bike service or oil change, km since, and when the next is due.
class BikeServicePanel extends StatelessWidget {
  const BikeServicePanel({
    super.key,
    required this.forecast,
    this.now,
    this.ai,
    this.onRefineWithAi,
    this.aiBusy = false,
    this.aiError,
  });

  final BikeServiceForecast forecast;
  final OutlookAiEstimate? ai;
  final VoidCallback? onRefineWithAi;
  final bool aiBusy;
  final String? aiError;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.location(context);
    final now = this.now ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final f = forecast;
    final oil = f.kind == BikeMaintenance.oil;
    final noun = f.noun;
    final nounCap = '${noun[0].toUpperCase()}${noun.substring(1)}';
    final date = DateFormat('d MMM yyyy');
    final section = oil ? OutlookSection.oil : OutlookSection.bike;

    final sinceLast = today.difference(f.lastDone).inDays;
    final ago = sinceLast <= 0
        ? 'today'
        : sinceLast == 1
        ? 'yesterday'
        : '$sinceLast days ago';

    int? daysToDue() => f.expectedDate?.difference(today).inDays;

    final dueOn = f.expectedDate == null
        ? ''
        : ' · ${DateFormat('d MMM yyyy').format(f.expectedDate!)}';
    final String headline;
    if (f.isOverdue) {
      headline = '$nounCap overdue by ${(-f.kmLeft!).round()} km$dueOn';
    } else if (f.expectedDate != null) {
      final days = daysToDue()!;
      headline = days <= 0
          ? '$nounCap due now$dueOn'
          : '$nounCap in about $days days$dueOn';
    } else if (f.kmLeft != null) {
      headline = '$nounCap in about ${f.kmLeft!.round()} km';
    } else {
      headline = 'Last $noun $ago';
    }

    final aiDate = oil ? ai?.oilChangeDate : ai?.bikeServiceDate;
    final aiNote = oil ? ai?.oilNote : ai?.bikeNote;

    final String explanation;
    if (f.intervalKm != null) {
      explanation =
          'Interval is the median km between your past ${noun}s'
          '${f.partialData ? '. Location data starts after the last $noun, so km since is undercounted' : ''}.';
    } else if (f.intervalDays != null) {
      explanation =
          'No riding data to measure km, so this uses the usual gap of '
          '${f.intervalDays} days between your ${noun}s.';
    } else {
      explanation =
          'Needs at least three ${noun}s on record to learn your usual '
          'interval. ${oil ? 'Entries titled "engine oil" count as oil changes.' : 'Only entries titled "servicing" count as services.'}';
    }

    return CategoryPanel(
      title: oil ? 'Oil change' : 'Bike service',
      trailing: 'last ${date.format(f.lastDone)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            headline,
            style: theme.textTheme.titleMedium?.copyWith(
              color: f.isOverdue ? palette.warning : accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatRow([
            if (f.expectedDate != null)
              _Stat(
                'Next $noun',
                DateFormat('d MMM yyyy').format(f.expectedDate!),
              ),
            _Stat(
              'Last $noun',
              '${DateFormat('d MMM').format(f.lastDone)} · $ago',
            ),
            if (f.hasRiding) _Stat('since then', '${f.kmSince.round()} km'),
            if (f.intervalKm != null)
              _Stat('usual interval', '${f.intervalKm!.round()} km')
            else if (f.intervalDays != null)
              _Stat('usual gap', '${f.intervalDays} days'),
            if (f.hasRiding)
              _Stat('riding lately', '${f.dailyKm.toStringAsFixed(1)} km/day'),
          ]),
          if (aiDate != null)
            _AiLine('AI: $noun around ${date.format(aiDate)}', aiNote ?? ''),
          const SizedBox(height: AppSpacing.sm),
          Text(
            explanation,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          _RefineFooter(
            refinedAt: ai?.refinedAt[section],
            stale: ai?.isOld(section, DateTime.now()) ?? false,
            busy: aiBusy,
            error: aiError,
            onRefine: onRefineWithAi,
            sends:
                'Sends your $noun entries, daily km ridden, your ride from '
                'your personal information and upcoming calendar events to '
                'your AI provider.',
          ),
        ],
      ),
    );
  }
}

/// The model's line under a baseline prediction, with its reason.
class _AiLine extends StatelessWidget {
  const _AiLine(this.headline, this.note);

  final String headline;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: palette.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  headline,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (note.isNotEmpty)
            Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

DateTime? _latest(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

/// Refine button, when it was last refined, and what gets sent.
class _RefineFooter extends StatelessWidget {
  const _RefineFooter({
    required this.refinedAt,
    required this.stale,
    required this.busy,
    required this.sends,
    this.error,
    this.onRefine,
  });

  final DateTime? refinedAt;
  final bool stale;
  final bool busy;
  final String? error;
  final VoidCallback? onRefine;
  final String sends;

  @override
  Widget build(BuildContext context) {
    if (onRefine == null && refinedAt == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final palette = context.palette;
    final day = DateFormat('d MMM');
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (refinedAt != null)
            Text(
              stale
                  ? 'Made ${day.format(refinedAt!)}. Refine again to update it.'
                  : 'Refined ${day.format(refinedAt!)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: stale ? palette.warning : palette.textMuted,
              ),
            ),
          if (error != null)
            Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.warning,
              ),
            ),
          if (onRefine != null) ...[
            TextButton.icon(
              onPressed: busy ? null : onRefine,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                refinedAt == null ? 'Refine with AI' : 'Refine again',
              ),
            ),
            Text(
              sends,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
