import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_ai.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';

/// Colour and icon each life forecast uses on its card and panel.
Color lifeForecastColor(BuildContext context, LifeForecastKind kind) =>
    switch (kind.group) {
      PredictionGroup.money => AppSemanticColors.expenses(context),
      PredictionGroup.body => AppSemanticColors.health(context),
      PredictionGroup.life => switch (kind) {
        LifeForecastKind.workArrival ||
        LifeForecastKind.commute ||
        LifeForecastKind.officeDay ||
        LifeForecastKind.weeklyKm ||
        LifeForecastKind.revisit => AppSemanticColors.location(context),
        LifeForecastKind.calendarLoad ||
        LifeForecastKind.freeTime => AppSemanticColors.calendar(context),
        LifeForecastKind.gaming => AppSemanticColors.gameActivity(context),
        _ => AppSemanticColors.insights(context),
      },
    };

IconData lifeForecastIcon(LifeForecastKind kind) => switch (kind) {
  LifeForecastKind.sleep => Icons.bedtime_rounded,
  LifeForecastKind.wakeTime => Icons.alarm_rounded,
  LifeForecastKind.weight => Icons.monitor_weight_rounded,
  LifeForecastKind.activity => Icons.directions_walk_rounded,
  LifeForecastKind.workouts => Icons.fitness_center_rounded,
  LifeForecastKind.heartRate => Icons.monitor_heart_rounded,
  LifeForecastKind.recovery => Icons.healing_rounded,
  LifeForecastKind.categories => Icons.pie_chart_rounded,
  LifeForecastKind.netMonth => Icons.account_balance_wallet_rounded,
  LifeForecastKind.billAlerts => Icons.notification_important_rounded,
  LifeForecastKind.fuelPrice => Icons.local_gas_station_rounded,
  LifeForecastKind.holidaySpend => Icons.celebration_rounded,
  LifeForecastKind.workArrival => Icons.work_history_rounded,
  LifeForecastKind.commute => Icons.route_rounded,
  LifeForecastKind.officeDay => Icons.apartment_rounded,
  LifeForecastKind.weeklyKm => Icons.two_wheeler_rounded,
  LifeForecastKind.revisit => Icons.place_rounded,
  LifeForecastKind.calendarLoad => Icons.event_busy_rounded,
  LifeForecastKind.freeTime => Icons.event_available_rounded,
  LifeForecastKind.gaming => Icons.sports_esports_rounded,
  LifeForecastKind.checklist => Icons.checklist_rounded,
  LifeForecastKind.checklistThemes => Icons.rule_rounded,
  LifeForecastKind.patterns => Icons.hub_rounded,
  LifeForecastKind.sleepSpend => Icons.shopping_bag_rounded,
  LifeForecastKind.bestDay => Icons.star_rounded,
  LifeForecastKind.burnout => Icons.local_fire_department_rounded,
};

/// What each refinement sends, shown under the refine button.
String lifeForecastSends(LifeForecastKind kind) => switch (kind) {
  LifeForecastKind.sleep || LifeForecastKind.wakeTime =>
    'Sends your nightly sleep rows (bed, wake, stages) to your AI provider.',
  LifeForecastKind.weight =>
    'Sends weight readings, daily steps and workouts, and your fitness goal '
        'to your AI provider.',
  LifeForecastKind.activity || LifeForecastKind.workouts =>
    'Sends daily steps, heart rate, calories and workouts to your AI provider.',
  LifeForecastKind.heartRate || LifeForecastKind.recovery =>
    'Sends daily heart rate and HRV with your sleep rows to your AI provider.',
  LifeForecastKind.categories =>
    'Sends spending per category per month to your AI provider.',
  LifeForecastKind.netMonth =>
    'Sends monthly income and spending totals and income entries to your AI '
        'provider.',
  LifeForecastKind.billAlerts =>
    'Sends each recurring bill and its recent payments to your AI provider.',
  LifeForecastKind.fuelPrice =>
    'Sends your fuel entries, with prices and notes, to your AI provider.',
  LifeForecastKind.holidaySpend =>
    'Sends calendar events and daily spending to your AI provider.',
  LifeForecastKind.workArrival =>
    'Sends your work arrival times, sleep rows and calendar events to your '
        'AI provider.',
  LifeForecastKind.commute =>
    'Sends your home-to-work trip times to your AI provider.',
  LifeForecastKind.officeDay =>
    'Sends your work visit dates and times to your AI provider.',
  LifeForecastKind.weeklyKm =>
    'Sends your daily riding distance to your AI provider.',
  LifeForecastKind.revisit =>
    'Sends visit dates for your most frequent places, with the names you gave '
        'them, to your AI provider.',
  LifeForecastKind.calendarLoad || LifeForecastKind.freeTime =>
    'Sends calendar event titles, times and places to your AI provider.',
  LifeForecastKind.gaming =>
    'Sends your daily gaming sessions to your AI provider.',
  LifeForecastKind.checklist || LifeForecastKind.checklistThemes =>
    'Sends checklist counts per week and category, with daily sleep, '
        'activity and spending rows, to your AI provider.',
  LifeForecastKind.patterns ||
  LifeForecastKind.sleepSpend ||
  LifeForecastKind.bestDay =>
    'Sends one joined row per day of sleep, steps, gaming, calendar hours '
        'and spending to your AI provider.',
  LifeForecastKind.burnout =>
    'Sends joined daily rows, work arrivals, calendar events and checklist '
        'counts to your AI provider.',
};

/// Full panel for one life forecast: the app's baseline, how it was worked
/// out, and the AI's own calculation when there is one.
class LifeForecastPanel extends StatelessWidget {
  const LifeForecastPanel({
    super.key,
    required this.forecast,
    this.ai,
    this.aiBusy = false,
    this.aiError,
    this.onRefineWithAi,
  });

  final LifeForecast forecast;
  final LifeAiItem? ai;
  final bool aiBusy;
  final String? aiError;
  final VoidCallback? onRefineWithAi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = lifeForecastColor(context, forecast.kind);
    final day = DateFormat('d MMM');
    final fresh = ai != null && ai!.isFreshFor(forecast, DateTime.now());

    return CategoryPanel(
      title: forecast.label,
      trailing: forecast.date == null ? null : day.format(forecast.date!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            forecast.headline,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: forecast.attention ? palette.warning : accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            forecast.detail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          if (ai != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 14, color: palette.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'AI: ${ai!.headline}'
                    '${ai!.detail.isEmpty ? '' : ' · ${ai!.detail}'}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (ai!.reasoning.isNotEmpty)
              Text(
                ai!.reasoning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          for (final note in forecast.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
          if (ai != null)
            Text(
              fresh
                  ? 'Refined ${day.format(ai!.refinedAt)}'
                  : 'Made ${day.format(ai!.refinedAt)}. Refine again to update it.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: fresh ? palette.textMuted : palette.warning,
              ),
            ),
          if (aiError != null)
            Text(
              aiError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.warning,
              ),
            ),
          if (onRefineWithAi != null) ...[
            TextButton.icon(
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
            Text(
              '${lifeForecastSends(forecast.kind)} The AI calculates from '
              'those rows itself.',
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
