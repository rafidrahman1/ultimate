import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/health/health_patterns.dart';
import 'package:personal/features/health/sleep_stage_stats.dart';
import 'package:personal/features/health/vitals_models.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/category/category_hero.dart';
import 'package:personal/shared/widgets/category/category_scroll.dart';
import 'package:personal/shared/widgets/category/day_bars.dart';
import 'package:personal/shared/widgets/category/trend_line.dart';

part 'health_vitals_slivers.dart';

final _number = NumberFormat.decimalPattern();

String _duration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
}

String _pct(double share) => '${(share * 100).round()}%';

// ── Sleep: stages and patterns ───────────────────────────────────────────

/// Where the night's sleep went: deep, REM and light, plus awake time.
class SleepStagesPanel extends StatelessWidget {
  const SleepStagesPanel({super.key, required this.stats});

  final SleepStageStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final deepColor = AppSemanticColors.health(context);
    final remColor = AppSemanticColors.result(context);
    final lightColor = palette.textMuted;

    int flex(double share) => (share * 1000).round();

    Widget legend(String label, Duration time, double share, Color color) =>
        Expanded(
          child: Semantics(
            label: '$label ${_duration(time)}, ${_pct(share)} of sleep',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _duration(time),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '$label · ${_pct(share)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    final efficiency = stats.avgEfficiency;
    return CategoryPanel(
      title: 'Sleep stages',
      trailing: '${stats.nights} nights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: flex(stats.deepShare).clamp(1, 1000),
                    child: ColoredBox(color: deepColor),
                  ),
                  Expanded(
                    flex: flex(stats.remShare).clamp(1, 1000),
                    child: ColoredBox(color: remColor),
                  ),
                  Expanded(
                    flex: flex(stats.lightShare).clamp(1, 1000),
                    child: ColoredBox(color: lightColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              legend('Deep', stats.avgDeep, stats.deepShare, deepColor),
              legend('REM', stats.avgRem, stats.remShare, remColor),
              legend('Light', stats.avgLight, stats.lightShare, lightColor),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            [
              if (efficiency != null)
                'Asleep ${_pct(efficiency)} of the time in bed',
              '${stats.avgAwakeEpisodes.toStringAsFixed(1)} wake-ups a night',
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Typical adults: deep about 13–23%, REM about 20–25%. '
            'A general guide; watches estimate stages.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Differences between groups of days, e.g. steps after short vs full nights.
class HealthPatternsPanel extends StatelessWidget {
  const HealthPatternsPanel({super.key, required this.patterns});

  final List<HealthPattern> patterns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.health(context);

    Widget side(String label, String value, int days, bool emphasised) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: emphasised ? accent : null,
                ),
              ),
              Text(
                '$label · $days days',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        );

    return CategoryPanel(
      title: 'Patterns',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in patterns.take(4)) ...[
            Text(
              p.title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                side(
                  p.labelA,
                  p.format(p.valueA),
                  p.daysA,
                  p.valueA > p.valueB,
                ),
                side(
                  p.labelB,
                  p.format(p.valueB),
                  p.daysB,
                  p.valueB > p.valueA,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            'Observations from this period only, not proven causes.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Connecting ───────────────────────────────────────────────────────────

/// Explains the extra data and asks for access, or says what's missing.
class ConnectVitalsCard extends StatelessWidget {
  const ConnectVitalsCard({
    super.key,
    required this.vitals,
    required this.onConnect,
    required this.connecting,
    this.focus,
  });

  final VitalsSummary? vitals;
  final VoidCallback onConnect;
  final bool connecting;

  /// The metrics this section cares about; a hint is shown if they're missing.
  final Set<VitalsMetric>? focus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.health(context);
    final connected = vitals?.isConnected ?? false;
    final missing = [
      for (final m in focus ?? VitalsMetric.values)
        if (!(vitals?.readMetrics.contains(m) ?? false)) m,
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_outline_rounded, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  connected
                      ? 'Some data isn’t shared yet'
                      : 'Add activity and heart data',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            connected
                ? 'Not allowed in Health Connect: '
                      '${missing.map((m) => m.label.toLowerCase()).join(', ')}.'
                : 'Steps, workouts, heart rate, weight and more from Samsung '
                      'Health, shown here and added to your monthly analysis '
                      'as summaries. You choose each type in Health Connect, '
                      'and it stays on this device.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonal(
            onPressed: connecting ? null : onConnect,
            child: Text(
              connecting
                  ? 'Waiting for Health Connect…'
                  : connected
                  ? 'Review access'
                  : 'Connect',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'If nothing appears, open Samsung Health, then Settings, then '
            'Health Connect, and turn on sharing for these types.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// What Health Connect is actually giving us, per metric. Helps tell "not
/// allowed" from "allowed but the watch hasn't synced".
class VitalsStatusPanel extends StatelessWidget {
  const VitalsStatusPanel({super.key, required this.vitals});

  final VitalsSummary? vitals;

  int _daysWith(VitalsSummary v, VitalsMetric m) => switch (m) {
    VitalsMetric.steps => v.days.where((d) => d.steps != null).length,
    VitalsMetric.heartRate => v.days.where((d) => d.avgHr != null).length,
    VitalsMetric.restingHeartRate =>
      v.days.where((d) => d.restingHr != null).length,
    VitalsMetric.hrv => v.days.where((d) => d.hrvMs != null).length,
    VitalsMetric.workouts => v.workoutDays,
    VitalsMetric.activeEnergy =>
      v.days.where((d) => d.activeKcal != null).length,
    VitalsMetric.distance =>
      v.days.where((d) => d.distanceMeters != null).length,
    VitalsMetric.weight => v.weights.length,
    VitalsMetric.oxygen => v.days.where((d) => d.spo2Avg != null).length,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final v = vitals;

    return Column(
      children: [
        for (final metric in VitalsMetric.values)
          Builder(
            builder: (context) {
              final allowed = v?.readMetrics.contains(metric) ?? false;
              final days = allowed && v != null ? _daysWith(v, metric) : 0;
              final apps = v?.sources[metric]?.join(', ');
              final unit = metric == VitalsMetric.weight
                  ? 'readings'
                  : metric == VitalsMetric.workouts
                  ? 'workout days'
                  : 'days';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      allowed
                          ? (days > 0
                                ? Icons.check_circle_rounded
                                : Icons.hourglass_empty_rounded)
                          : Icons.block_rounded,
                      size: 20,
                      color: allowed && days > 0
                          ? AppSemanticColors.health(context)
                          : palette.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            !allowed
                                ? 'Not allowed'
                                : days == 0
                                ? 'Allowed, no data this period'
                                : '$days $unit${apps == null || apps.isEmpty ? '' : ' · $apps'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

// ── Activity ─────────────────────────────────────────────────────────────
