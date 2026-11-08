import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/formatting.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/ui/dashboard_delta.dart';
import 'package:personal/features/dashboard/view/dashboard_layout_service.dart';
import 'package:personal/features/dashboard/view/dashboard_view_data.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_refresh.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/features/results/pipeline/cross_analysis.dart';
import 'package:personal/shared/widgets/data_freshness_indicator.dart';
import 'package:personal/shared/widgets/donut_chart.dart';
import 'package:personal/shared/widgets/sparkline.dart';

/// The Dashboard's top board: a status strip, then one tile per source with
/// data. Tiles show the headline figure; tapping one opens its analysis card.
class DashboardTileBoard extends ConsumerWidget {
  const DashboardTileBoard({
    super.key,
    required this.data,
    required this.onOpenCard,
  });

  final DashboardViewData data;
  final ValueChanged<DashboardCardId> onOpenCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final tiles = ref.watch(homeTileStatsProvider);
    final lastRefresh = ref.watch(homeLastRefreshProvider);
    final stable = data.stableMonth;
    final verdict = stable == null || !stable.canEvaluate
        ? 'Month in progress'
        : stable.isStable
        ? 'Stable month'
        : 'Unstable month';
    final verdictColor = stable != null && stable.canEvaluate
        ? (stable.isStable
              ? AppSemanticColors.health(context)
              : palette.warning)
        : palette.textPrimary;
    final missing = [
      for (final d in data.domains)
        if (!d.hasData) d.label,
    ];

    final health = data.health;
    final money = data.financial;
    final mobility = data.mobility;
    final gaming = data.gaming;
    final calendar = data.calendar;
    final screen = data.screenTime;

    final small = <Widget>[
      if (mobility != null) _mobilityTile(context, mobility),
      if (gaming != null) _gamingTile(context, gaming),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                verdict,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: verdictColor,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                data.periodLabel,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        DataFreshnessIndicator(updatedAt: lastRefresh, prefix: 'Last refresh'),
        const SizedBox(height: AppSpacing.md),
        if (health != null)
          _SleepTile(
            section: health,
            stat: tiles[HomeFeatureId.health],
            onTap: () => onOpenCard(DashboardCardId.health),
          ),
        if (money != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ExpensesTile(
            section: money,
            onTap: () => onOpenCard(DashboardCardId.financial),
          ),
        ],
        if (small.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < small.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(child: small[i]),
                ],
              ],
            ),
          ),
        ],
        if (screen != null || calendar != null) ...[
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (screen != null)
                  Expanded(child: _screenTile(context, screen)),
                if (screen != null && calendar != null)
                  const SizedBox(width: AppSpacing.md),
                if (calendar != null)
                  Expanded(child: _calendarTile(context, calendar)),
              ],
            ),
          ),
        ],
        if (data.crossInsights.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _CrossChecksCard(insights: data.crossInsights),
        ],
        if (missing.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'No data yet: ${missing.join(' · ')}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _mobilityTile(BuildContext context, DashboardMobilityAnalysis m) {
    final color = AppSemanticColors.location(context);
    final tracksWork = m.workDays > 0;
    return _StatRowsTile(
      title: 'Mobility',
      onTap: () => onOpenCard(DashboardCardId.mobility),
      rows: [
        _StatRow(
          Icons.two_wheeler_rounded,
          m.motorcycleKm.round().toString(),
          'km',
          color,
        ),
        _StatRow(
          Icons.schedule_rounded,
          m.travelTimeHours.toStringAsFixed(1),
          'h travelling',
          color,
        ),
        if (tracksWork)
          _StatRow(
            Icons.work_outline_rounded,
            '${m.lateArrivals}/${m.workDays}',
            'late days',
            m.lateArrivals > 0 ? context.palette.warning : color,
          ),
      ],
    );
  }

  Widget _gamingTile(BuildContext context, DashboardGamingAnalysis g) {
    final color = AppSemanticColors.gameActivity(context);
    final hours = g.totalPlayHours;
    return _StatRowsTile(
      title: 'Gaming',
      onTap: () => onOpenCard(DashboardCardId.gaming),
      rows: [
        _StatRow(
          Icons.sports_esports_rounded,
          hours >= 1 ? hours.toStringAsFixed(1) : '${(hours * 60).round()}',
          hours >= 1 ? 'h played' : 'min played',
          color,
        ),
        _StatRow(
          Icons.play_circle_outline_rounded,
          '${g.sessionCount}',
          g.sessionCount == 1 ? 'session' : 'sessions',
          color,
        ),
        if (g.byGame.isNotEmpty)
          _StatRow(
            Icons.emoji_events_outlined,
            g.byGame.first.label,
            'most played',
            color,
          ),
      ],
    );
  }

  Widget _screenTile(BuildContext context, DashboardScreenTimeAnalysis s) {
    final palette = context.palette;
    final color = AppSemanticColors.primary(context);
    final change = s.avgChangeHours;
    final worse = change != null && change > 0.25;
    return _StatRowsTile(
      title: 'Screen time',
      onTap: () => onOpenCard(DashboardCardId.screenTime),
      rows: [
        _StatRow(
          Icons.hourglass_bottom_rounded,
          hoursLabel(s.avgHoursPerDay),
          'a day',
          color,
        ),
        if (change != null && change.abs() >= 0.1)
          _StatRow(
            change > 0
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            hoursLabel(change.abs()),
            change > 0 ? 'more than last month' : 'less than last month',
            worse ? palette.warning : palette.statusGood,
          ),
        if (s.topApps.isNotEmpty)
          _StatRow(Icons.apps_rounded, s.topApps.first.label, 'top app', color),
      ],
    );
  }

  Widget _calendarTile(BuildContext context, DashboardCalendarAnalysis c) {
    final color = AppSemanticColors.calendar(context);
    return _StatRowsTile(
      title: 'Calendar',
      onTap: () => onOpenCard(DashboardCardId.calendar),
      rows: [
        _StatRow(
          Icons.event_rounded,
          '${c.majorEventCount}',
          'major events',
          color,
        ),
        _StatRow(
          Icons.beach_access_outlined,
          '${c.holidayCount}',
          c.holidayCount == 1 ? 'holiday' : 'holidays',
          color,
        ),
      ],
    );
  }
}

/// How the sources move together: sleep vs screen time vs spending and so on.
class _CrossChecksCard extends StatelessWidget {
  const _CrossChecksCard({required this.insights});

  final List<CrossInsight> insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final notable = insights.where((e) => e.notable).take(6).toList();
    final quiet = insights.where((e) => !e.notable).toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.cardLarge + 8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cross-checks',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'How your sources move together this month',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (notable.isEmpty)
              Text(
                'No strong links yet. More overlapping days will sharpen this.',
                style: theme.textTheme.bodyMedium,
              ),
            for (final e in notable)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      e.tone == CrossTone.watch
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 20,
                      color: e.tone == CrossTone.watch
                          ? palette.warning
                          : palette.statusGood,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            e.detail,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (quiet.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No clear link: ${quiet.map((e) => e.title).join(' · ')}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared tile surface: title with a chevron, content below, no border.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.onTap,
    required this.child,
    this.padding = AppSpacing.xl,
  });

  final double padding;
  final String title;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '$title. Show details',
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.cardLarge + 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: palette.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero tile: big average sleep, change vs last month, area chart.
class _SleepTile extends StatelessWidget {
  const _SleepTile({
    required this.section,
    required this.stat,
    required this.onTap,
  });

  final DashboardHealthAnalysis section;
  final HomeTileStat? stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final color = AppSemanticColors.health(context);
    final delta = DashboardDelta.from(
      section.sleepDebtChangeHours,
      (v) => '${v.toStringAsFixed(1)} h',
      lowerIsBetter: true,
    );
    final deltaColor = switch (delta?.improved) {
      true => palette.statusGood,
      false => palette.warning,
      _ => palette.textMuted,
    };
    final series = stat?.series;

    return _Tile(
      title: 'Sleep',
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    stat?.value ?? '—',
                    style: context.statDisplay.copyWith(fontSize: 34),
                  ),
                ),
                Text(
                  'avg sleep · ${section.nightsTracked} nights',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (delta != null)
                  Row(
                    children: [
                      Icon(
                        delta.rising
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 16,
                        color: deltaColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${delta.text} ',
                                style: TextStyle(
                                  color: deltaColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: 'sleep debt vs last month',
                                style: TextStyle(color: palette.textMuted),
                              ),
                            ],
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '${section.nightsBelowTarget} below 7 h target',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (series != null) ...[
            const SizedBox(width: AppSpacing.md),
            Sparkline(values: series, color: color, width: 120, height: 64),
          ],
        ],
      ),
    );
  }
}

/// Expenses tile: ranked categories on the left, donut with the total.
class _ExpensesTile extends StatelessWidget {
  const _ExpensesTile({required this.section, required this.onTap});

  final DashboardFinancialAnalysis section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final cats = section.categoryConcentration;
    final colors = [
      AppSemanticColors.expenses(context),
      AppSemanticColors.location(context),
      AppSemanticColors.health(context),
      AppSemanticColors.calendar(context),
      AppSemanticColors.gameActivity(context),
    ];
    final prefix = currencyPrefix(section.currency);
    final total =
        '$prefix${NumberFormat.decimalPattern().format(section.totalSpent.round())}';
    final shown = cats.take(4).toList();
    final more = cats.length - shown.length;

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors[i % colors.length],
                  ),
                  child: const SizedBox.square(dimension: 10),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    shown[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      shown[i].displayValue,
                      maxLines: 1,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (more > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ $more more',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ),
      ],
    );

    final donut = DonutChart(
      values: [for (final c in shown) c.value],
      colors: colors,
      size: 116,
      center: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total',
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            Text(
              total,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );

    return _Tile(
      title: 'Expenses',
      onTap: onTap,
      child: shown.isEmpty
          ? Text(total, style: context.statDisplay.copyWith(fontSize: 30))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: list),
                const SizedBox(width: AppSpacing.lg),
                donut,
              ],
            ),
    );
  }
}

class _StatRow {
  const _StatRow(this.icon, this.value, this.unit, this.color);

  final IconData icon;
  final String value;
  final String unit;
  final Color color;
}

/// Compact tile of stacked icon + value + unit rows.
class _StatRowsTile extends StatelessWidget {
  const _StatRowsTile({
    required this.title,
    required this.rows,
    required this.onTap,
  });

  final String title;
  final List<_StatRow> rows;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return _Tile(
      title: title,
      onTap: onTap,
      padding: AppSpacing.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(r.icon, size: 20, color: r.color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: r.value,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: ' ${r.unit}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
