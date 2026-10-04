import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/category/category_hero.dart';
import 'package:personal/shared/widgets/category/category_scroll.dart';
import 'package:personal/shared/widgets/category/day_bars.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/shared/widgets/pull_to_refresh.dart';

class HealthDataScreen extends ConsumerWidget {
  const HealthDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(healthAuthorizationProvider);
    final dataAsync = ref.watch(monthlyHealthDataProvider);
    final period = ref.watch(analysisPeriodProvider);

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Health',
        extraActions: [
          AppBarCircularAction(
            icon: Icons.refresh,
            onPressed: () =>
                ref.read(monthlyHealthDataProvider.notifier).refresh(),
          ),
        ],
      ),
      body: authAsync.when(
        data: (isAuthorized) {
          if (!isAuthorized) {
            return StatusMessage(
              icon: Icons.lock_outline,
              title: 'Health permissions required',
              subtitle: 'Personal needs Health Connect access to read sleep.',
              action: FilledButton(
                onPressed: () =>
                    ref.read(monthlyHealthDataProvider.notifier).refresh(),
                child: const Text('Grant access'),
              ),
            );
          }
          return dataAsync.when(
            data: (result) => PullToRefresh(
              onRefresh: () =>
                  ref.read(monthlyHealthDataProvider.notifier).refresh(),
              child: _MonthlyHealthBody(fetch: result, period: period),
            ),
            loading: () =>
                const CardListSkeleton(cardHeights: [210, 200, 72, 72, 72]),
            error: (err, _) => StatusMessage(
              icon: Icons.error_outline,
              title: 'Could not load health data',
              subtitle: err.toString(),
              action: OutlinedButton(
                onPressed: () =>
                    ref.read(monthlyHealthDataProvider.notifier).refresh(),
                child: const Text('Try again'),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Authorization failed',
          subtitle: err.toString(),
        ),
      ),
    );
  }
}

class _MonthlyHealthBody extends StatelessWidget {
  const _MonthlyHealthBody({required this.fetch, required this.period});

  final MonthlyHealthFetchResult fetch;
  final AnalysisPeriod period;

  @override
  Widget build(BuildContext context) {
    if (!fetch.hasData) {
      return StatusMessage(
        icon: Icons.monitor_heart_outlined,
        title: 'No health data yet',
        subtitle:
            'Sync Samsung Health and check back for ${period.dataRangeLabel}.',
        action: Consumer(
          builder: (context, ref, _) => OutlinedButton(
            onPressed: () =>
                ref.read(monthlyHealthDataProvider.notifier).refresh(),
            child: const Text('Refresh'),
          ),
        ),
      );
    }

    final summary = MonthlyHealthSummary.fromFetch(fetch);
    final accent = AppSemanticColors.health(context);
    final palette = context.palette;
    final nights = summary.dailySleep.where((d) => d.hasData).toList();
    final days = buildDayBars([
      for (final n in nights)
        (date: n.wakeDate, value: n.session!.duration.inMinutes / 60),
    ], period.dataMonthStart);

    Duration? average;
    DailySleepEntry? best;
    DailySleepEntry? shortest;
    String? avgBed;
    String? avgWake;
    if (nights.isNotEmpty) {
      final total = nights.fold<int>(
        0,
        (sum, n) => sum + n.session!.duration.inMinutes,
      );
      average = Duration(minutes: (total / nights.length).round());
      best = nights.reduce(
        (a, b) => a.session!.duration >= b.session!.duration ? a : b,
      );
      shortest = nights.reduce(
        (a, b) => a.session!.duration <= b.session!.duration ? a : b,
      );
      avgBed = _averageClock(nights.map((n) => n.session!.startTime));
      avgWake = _averageClock(nights.map((n) => n.session!.endTime));
    }
    final newestFirst = nights.reversed.toList();

    return CategoryScroll(
      reserveFab: false,
      slivers: [
        categoryBox(
          CategoryHero(
            accent: accent,
            icon: Icons.bedtime_rounded,
            label: 'Average sleep',
            value: average == null ? '—' : formatDuration(average),
            caption:
                '${summary.sleepNightsTracked} of ${summary.dayCount} nights tracked',
            footnote: summary.periodRangeLabel,
            stats: [
              if (avgBed != null) HeroStat('Avg bedtime', avgBed),
              if (avgWake != null) HeroStat('Avg wake', avgWake),
              if (best != null)
                HeroStat('Best night', formatDuration(best.session!.duration)),
              if (shortest != null && nights.length > 1)
                HeroStat(
                  'Shortest',
                  formatDuration(shortest.session!.duration),
                ),
            ],
          ),
        ),
        categoryBox(
          CategoryPanel(
            title: 'Sleep by night',
            trailing: 'Samsung Health',
            child: DayBars(
              data: days,
              color: accent,
              target: 7,
              targetLabel: '7 h',
              format: (v) => v == 0 ? 'No data' : _hours(v),
              emptyLabel: 'No sleep recorded this month',
            ),
          ),
        ),
        if (summary.sleepNightsMissing > 0)
          categoryBox(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${summary.sleepNightsMissing} nights without sleep data',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.textMuted),
              ),
            ),
            bottom: AppSpacing.md,
          ),
        if (newestFirst.isNotEmpty) ...[
          categoryBox(const CategoryTitle('Nights'), bottom: AppSpacing.xs),
          categoryBox(
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < newestFirst.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 16, color: palette.border),
                    _NightRow(entry: newestFirst[i], accent: accent),
                  ],
                ],
              ),
            ),
          ),
        ],
        categoryBox(
          AnalysisDataLink(
            promptText: summary.toAnalysisPromptText(),
            title: 'Health data for analysis',
            accent: accent,
            icon: Icons.monitor_heart_outlined,
          ),
        ),
      ],
    );
  }
}

class _NightRow extends StatelessWidget {
  const _NightRow({required this.entry, required this.accent});

  final DailySleepEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final session = entry.session!;
    final hours = session.duration.inMinutes / 60;
    final palette = context.palette;
    final color = hours < 6
        ? palette.warning
        : hours >= 7
        ? accent
        : palette.textPrimary;

    return CategoryRow(
      icon: Icons.bedtime_outlined,
      accent: accent,
      title: dayLabel(entry.wakeDate),
      subtitle:
          'Bed ${formatTime(session.startTime)} → wake ${formatTime(session.endTime)}',
      trailing: formatDuration(session.duration),
      trailingColor: color,
    );
  }
}

String _hours(double hours) {
  final minutes = (hours * 60).round();
  return formatDuration(Duration(minutes: minutes));
}

/// Mean clock time, treating hours before noon as "after midnight" so
/// bedtimes either side of 00:00 average sensibly.
String _averageClock(Iterable<DateTime> times) {
  var total = 0.0;
  var count = 0;
  for (final t in times) {
    var minutes = t.hour * 60 + t.minute;
    if (t.hour < 12) minutes += 24 * 60;
    total += minutes;
    count++;
  }
  final mean = (total / count).round() % (24 * 60);
  return '${(mean ~/ 60).toString().padLeft(2, '0')}:'
      '${(mean % 60).toString().padLeft(2, '0')}';
}
