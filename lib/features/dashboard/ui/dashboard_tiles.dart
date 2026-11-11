import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/formatting.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/ui/dashboard_delta.dart';
import 'package:personal/features/dashboard/view/dashboard_advice_facts.dart';
import 'package:personal/features/dashboard/view/dashboard_layout_service.dart';
import 'package:personal/features/dashboard/view/dashboard_view_data.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/forecasts/reminders/advice_reminder_service.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/features/results/ai/cross_advice_ai.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/shared/widgets/donut_chart.dart';
import 'package:personal/shared/widgets/sparkline.dart';

part 'dashboard_cross_advice_card.dart';
part 'dashboard_tile_widgets.dart';

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
          ],
        ),
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
        if (data.hasAnyData) ...[
          const SizedBox(height: AppSpacing.md),
          _CrossAdviceCard(data: data),
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
