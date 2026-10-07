part of 'expense_panels.dart';

/// When the next fuel purchase is likely, from riding distance where the
/// location data allows, else from past refuel gaps.
class FuelForecastPanel extends StatelessWidget {
  const FuelForecastPanel({
    super.key,
    required this.forecast,
    required this.money,
    this.now,
    this.aiEstimate,
    this.aiBusy = false,
    this.aiError,
    this.onRefineWithAi,
  });

  final FuelForecast forecast;
  final NumberFormat money;
  final DateTime? now;

  /// The model's adjusted estimate, if one was requested for this forecast.
  final FuelAiEstimate? aiEstimate;
  final bool aiBusy;
  final String? aiError;

  /// Null hides the button (no AI provider set up).
  final VoidCallback? onRefineWithAi;

  static String _headline(int days) => days < 0
      ? 'Overdue by ${-days} ${-days == 1 ? 'day' : 'days'}'
      : days == 0
      ? 'Expected today'
      : days == 1
      ? 'Expected tomorrow'
      : 'In $days days';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final today = now ?? DateTime.now();
    final days = forecast.daysUntil(today);
    final day = DateFormat('EEE d MMM');
    final sameDay = forecast.earliestDate == forecast.latestDate;
    final range = sameDay
        ? day.format(forecast.expectedDate)
        : '${day.format(forecast.earliestDate)} – ${day.format(forecast.latestDate)}';
    final distance = forecast.distance;
    final ai = aiEstimate;

    return CategoryPanel(
      title: 'Next fuel purchase',
      trailing: forecast.isRoughGuess ? 'rough guess' : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _headline(days),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: days < 0 ? palette.warning : null,
            ),
          ),
          Text(
            'Around ${money.format(forecast.typicalAmount)} · $range',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _StatRow([
            if (distance != null) ...[
              _Stat('Left in tank', '~${distance.kmLeft.round()} km'),
              _Stat(
                'Since last refuel',
                '${distance.kmSinceLastRefuel.round()} km',
              ),
              _Stat('Riding lately', '${distance.dailyKm.round()} km/day'),
            ] else ...[
              _Stat(
                'Usually every',
                '${forecast.typicalIntervalDays.round()} days',
              ),
              _Stat('Last refuel', day.format(forecast.lastRefuel)),
            ],
            if (forecast.typicalLitres != null &&
                forecast.lastRatePerLitre != null)
              _Stat(
                'Usual refill',
                '${forecast.typicalLitres!.toStringAsFixed(1)} L at '
                    '${forecast.lastRatePerLitre!.toStringAsFixed(0)}/L',
              ),
            if (distance?.kmPerLitre != null)
              _Stat(
                'Mileage',
                '${distance!.kmPerLitre!.toStringAsFixed(1)} km/L',
              ),
            _Stat('Based on', '${forecast.refuelCount} refuels'),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text(
            distance != null
                ? 'From how far past ${distance.kmPerLitre != null ? 'litres' : 'refills'} lasted, the km ridden since, and '
                      'your usual riding for each weekday. Location data runs '
                      'to ${day.format(distance.locationThrough)}.'
                : 'From the gaps between refuels. Load location data to '
                      'predict from distance ridden.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
          if (ai != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'AI estimate: ${day.format(ai.expectedDate)} · '
              '${money.format(ai.amount)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              ai.isStaleFor(forecast)
                  ? 'Made ${day.format(ai.createdAt)}, before your latest '
                        'refuel. Refine again to update it.'
                  : 'Refined ${day.format(ai.createdAt)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: ai.isStaleFor(forecast)
                    ? palette.warning
                    : palette.textMuted,
              ),
            ),
            if (ai.reasoning.isNotEmpty)
              Text(
                ai.reasoning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
          ],
          if (aiError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              aiError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.warning,
              ),
            ),
          ],
          if (onRefineWithAi != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: aiBusy ? null : onRefineWithAi,
                icon: aiBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(ai == null ? 'Refine with AI' : 'Refine again'),
              ),
            ),
            Text(
              'Sends refuel dates, riding distance and the next three weeks of '
              'calendar events to your AI provider.',
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

/// Bills and subscriptions expected to be charged soon.
class UpcomingChargesPanel extends StatelessWidget {
  const UpcomingChargesPanel({
    super.key,
    required this.charges,
    required this.money,
    this.now,
    this.ai,
    this.onRefineWithAi,
    this.aiBusy = false,
    this.aiError,
  });

  final List<UpcomingCharge> charges;
  final NumberFormat money;
  final OutlookAiEstimate? ai;
  final VoidCallback? onRefineWithAi;
  final bool aiBusy;
  final String? aiError;
  final DateTime? now;

  static const _shown = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.expenses(context);
    final today = now ?? DateTime.now();
    final shown = charges.take(_shown).toList();
    final total = charges.fold<double>(0, (sum, c) => sum + c.amount);
    final date = DateFormat('d MMM');

    String when(UpcomingCharge c) {
      final days = c.daysUntil(today);
      if (days < 0) return '${-days}d late';
      if (days == 0) return 'today';
      if (days == 1) return 'tomorrow';
      return 'in $days days';
    }

    return CategoryPanel(
      title: 'Coming up',
      trailing: '${money.format(total)} in 30 days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in shown)
            CategoryRow(
              icon: c.declared ? Icons.repeat_rounded : Icons.event_repeat,
              accent: c.isOverdue(today) ? palette.warning : accent,
              title: c.label,
              subtitle: () {
                final base =
                    '${money.format(c.amount)} ${c.cadence} · '
                    '${date.format(c.expectedDate)}';
                final refined = ai?.billFor(c.label);
                return refined == null
                    ? base
                    : '$base\nAI: ${money.format(refined.amount)} · '
                          '${date.format(refined.expectedDate)}';
              }(),
              trailing: when(c),
            ),
          if (charges.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${charges.length - shown.length} more',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ),
          if (ai != null && ai!.bills.isNotEmpty && ai!.billsNote.isNotEmpty)
            _AiLine('AI note', ai!.billsNote),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'From Cashew recurring entries and from spending that repeats at a '
            'steady gap and amount. Fuel has its own forecast.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          _RefineFooter(
            refinedAt: ai?.refinedAt[OutlookSection.bills],
            stale: ai?.isOld(OutlookSection.bills, DateTime.now()) ?? false,
            busy: aiBusy,
            error: aiError,
            onRefine: onRefineWithAi,
            sends:
                'Sends these bills and upcoming calendar events to your '
                'AI provider.',
          ),
        ],
      ),
    );
  }
}
