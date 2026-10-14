part of 'health_vitals_sections.dart';

IconData _workoutIcon(String type) {
  final t = type.toUpperCase();
  if (t.contains('RUN')) return Icons.directions_run_rounded;
  if (t.contains('WALK') || t.contains('HIK')) {
    return Icons.directions_walk_rounded;
  }
  if (t.contains('BIK') || t.contains('CYCL')) {
    return Icons.directions_bike_rounded;
  }
  if (t.contains('SWIM')) return Icons.pool_rounded;
  if (t.contains('STRENGTH') || t.contains('WEIGHT')) {
    return Icons.fitness_center_rounded;
  }
  if (t.contains('YOGA') || t.contains('PILATES') || t.contains('STRETCH')) {
    return Icons.self_improvement_rounded;
  }
  return Icons.sports_score_rounded;
}

List<Widget> activitySlivers(
  BuildContext context,
  VitalsSummary vitals,
  DateTime periodStart,
) {
  final accent = AppSemanticColors.health(context);
  final other = AppSemanticColors.result(context);
  final theme = Theme.of(context);
  final palette = context.palette;
  final average = vitals.averageSteps;
  final best = vitals.bestStepDay;
  final km = vitals.totalDistanceKm;
  final kcal = vitals.totalActiveKcal;
  final timeFormat = DateFormat('h:mm a');

  final stepBars = buildDayBars([
    for (final d in vitals.stepDays) (date: d.date, value: d.steps!.toDouble()),
  ], periodStart);
  final groups = groupByDay(vitals.workouts, (w) => w.start);

  return [
    if (average != null)
      categoryBox(
        CategoryHero(
          accent: accent,
          icon: Icons.directions_walk_rounded,
          label: 'Average steps',
          value: _number.format(average.round()),
          unit: 'a day',
          caption:
              '${vitals.stepDays.length} of ${vitals.days.length} days tracked',
          footnote: vitals.periodRangeLabel,
          stats: [
            if (best != null)
              HeroStat(
                'Best day',
                '${_number.format(best.steps)} · ${DateFormat('d MMM').format(best.date)}',
              ),
            HeroStat('10,000+ days', '${vitals.daysWithSteps(10000)}'),
            if (km != null) HeroStat('Distance', '${km.toStringAsFixed(1)} km'),
            if (kcal != null)
              HeroStat('Active energy', '${_number.format(kcal.round())} kcal'),
          ],
        ),
      ),
    if (average != null)
      categoryBox(
        CategoryPanel(
          title: 'Steps by day',
          child: DayBars(
            data: stepBars,
            color: accent,
            format: (v) =>
                v == 0 ? 'No data' : '${_number.format(v.round())} steps',
            emptyLabel: 'No steps recorded this period',
          ),
        ),
      ),
    if (vitals.workouts.isNotEmpty) ...[
      categoryBox(
        CategoryPanel(
          title: 'Workouts',
          trailing:
              '${vitals.workouts.length} · ${_duration(vitals.totalWorkoutTime)}',
          child: BreakdownBars(
            color: other,
            items: [
              for (final t in vitals.workoutsByType)
                (
                  label: t.label,
                  value: t.duration.inMinutes.toDouble(),
                  display: '${t.count}× · ${_duration(t.duration)}',
                ),
            ],
          ),
        ),
      ),
      categoryBox(const CategoryTitle('Sessions'), bottom: AppSpacing.xs),
      categoryList(
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return DayGroup(
            date: group.key,
            accent: accent,
            total: _duration(
              group.value.fold(Duration.zero, (sum, w) => sum + w.duration),
            ),
            children: [
              for (final w in group.value)
                CategoryRow(
                  icon: _workoutIcon(w.type),
                  accent: accent,
                  title: w.label,
                  subtitle:
                      '${timeFormat.format(w.start)} → ${timeFormat.format(w.end)}',
                  detail: [
                    if (w.distanceMeters != null)
                      '${(w.distanceMeters! / 1000).toStringAsFixed(2)} km',
                    if (w.kcal != null) '${w.kcal!.round()} kcal',
                  ].join(' · '),
                  trailing: _duration(w.duration),
                ),
            ],
          );
        },
      ),
    ] else if (vitals.readMetrics.contains(VitalsMetric.workouts))
      categoryBox(
        Text(
          'No workouts recorded this period.',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
        ),
      ),
    if (average == null && vitals.workouts.isEmpty)
      categoryBox(
        Text(
          vitals.readMetrics.contains(VitalsMetric.steps)
              ? 'No steps recorded this period.'
              : 'Steps aren’t shared with Personal yet.',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
        ),
      ),
  ];
}

// ── Heart ────────────────────────────────────────────────────────────────

List<Widget> heartSlivers(BuildContext context, VitalsSummary vitals) {
  final accent = AppSemanticColors.health(context);
  final other = AppSemanticColors.result(context);
  final theme = Theme.of(context);
  final palette = context.palette;

  final resting = vitals.averageRestingHr;
  final overall = vitals.averageHr;
  final hrv = vitals.averageHrv;
  final spo2 = vitals.averageSpo2;
  final peak = vitals.peakHr;
  final low = vitals.averageMinHr;

  List<TrendPoint> series(double? Function(DailyVitals) pick) => [
    for (final d in vitals.days) TrendPoint(d.date, pick(d)),
  ];

  final hasHeartData = resting != null || overall != null || hrv != null;
  final headline = resting ?? overall;

  return [
    if (headline != null)
      categoryBox(
        CategoryHero(
          accent: accent,
          icon: Icons.favorite_rounded,
          label: resting != null ? 'Resting heart rate' : 'Average heart rate',
          value: headline.toStringAsFixed(0),
          unit: 'bpm',
          caption: 'average over the period',
          footnote: vitals.periodRangeLabel,
          stats: [
            if (hrv != null) HeroStat('HRV', '${hrv.toStringAsFixed(0)} ms'),
            if (overall != null && resting != null)
              HeroStat('Daily average', '${overall.toStringAsFixed(0)} bpm'),
            if (low != null)
              HeroStat('Daily low', '${low.toStringAsFixed(0)} bpm'),
            if (peak != null) HeroStat('Peak', '$peak bpm'),
            if (spo2 != null)
              HeroStat('Blood oxygen', '${spo2.toStringAsFixed(1)}%'),
          ],
        ),
      ),
    if (resting != null)
      categoryBox(
        CategoryPanel(
          title: 'Resting heart rate',
          child: TrendLine(
            data: series((d) => d.restingHr?.toDouble()),
            color: accent,
            format: (v) => '${v.round()} bpm',
          ),
        ),
      ),
    if (overall != null)
      categoryBox(
        CategoryPanel(
          title: 'Heart rate by day',
          trailing: 'average',
          child: TrendLine(
            data: series((d) => d.avgHr?.toDouble()),
            color: other,
            format: (v) => '${v.round()} bpm',
          ),
        ),
      ),
    if (hrv != null)
      categoryBox(
        CategoryPanel(
          title: 'Heart rate variability',
          trailing: 'RMSSD',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TrendLine(
                data: series((d) => d.hrvMs),
                color: accent,
                format: (v) => '${v.round()} ms',
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Compare with your own baseline, not with other people.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    if (spo2 != null)
      categoryBox(
        CategoryPanel(
          title: 'Blood oxygen',
          child: TrendLine(
            data: series((d) => d.spo2Avg),
            color: other,
            format: (v) => '${v.toStringAsFixed(1)}%',
          ),
        ),
      ),
    if (!hasHeartData && spo2 == null)
      categoryBox(
        Text(
          vitals.readMetrics.contains(VitalsMetric.heartRate) ||
                  vitals.readMetrics.contains(VitalsMetric.restingHeartRate)
              ? 'No heart data recorded this period.'
              : 'Heart rate isn’t shared with Personal yet.',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
        ),
      ),
  ];
}

// ── Body ─────────────────────────────────────────────────────────────────

List<Widget> bodySlivers(BuildContext context, VitalsSummary vitals) {
  final accent = AppSemanticColors.health(context);
  final theme = Theme.of(context);
  final palette = context.palette;
  final latest = vitals.latestWeight;
  final change = vitals.weightChangeKg;

  // One point per period day (the last reading of the day); readings before
  // the period only feed the change figure.
  final byDay = <DateTime, double>{};
  for (final w in vitals.weights) {
    final day = DateTime(w.time.year, w.time.month, w.time.day);
    if (day.isBefore(vitals.days.first.date)) continue;
    byDay[day] = w.kg;
  }
  final inPeriod = vitals.weights
      .where((w) => !w.time.isBefore(vitals.days.first.date))
      .toList()
      .reversed
      .toList();

  return [
    if (latest != null)
      categoryBox(
        CategoryHero(
          accent: accent,
          icon: Icons.monitor_weight_outlined,
          label: 'Latest weight',
          value: latest.kg.toStringAsFixed(1),
          unit: 'kg',
          caption: DateFormat('d MMM').format(latest.time),
          footnote: vitals.periodRangeLabel,
          stats: [
            if (change != null)
              HeroStat(
                'Change',
                '${change >= 0 ? '+' : '−'}${change.abs().toStringAsFixed(1)} kg',
              ),
            HeroStat('Readings', '${inPeriod.length}'),
          ],
        ),
      ),
    if (byDay.length >= 2)
      categoryBox(
        CategoryPanel(
          title: 'Weight',
          child: TrendLine(
            data: [
              for (final d in vitals.days) TrendPoint(d.date, byDay[d.date]),
            ],
            color: accent,
            maxGap: 40,
            format: (v) => '${v.toStringAsFixed(1)} kg',
          ),
        ),
      ),
    if (inPeriod.isNotEmpty) ...[
      categoryBox(const CategoryTitle('Readings'), bottom: AppSpacing.xs),
      categoryBox(
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < inPeriod.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: 16, color: palette.border),
                CategoryRow(
                  icon: Icons.monitor_weight_outlined,
                  accent: accent,
                  title: dayLabel(inPeriod[i].time),
                  trailing: '${inPeriod[i].kg.toStringAsFixed(1)} kg',
                ),
              ],
            ],
          ),
        ),
      ),
    ] else
      categoryBox(
        Text(
          vitals.readMetrics.contains(VitalsMetric.weight)
              ? 'No weight recorded this period.'
              : 'Weight isn’t shared with Personal yet.',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
        ),
      ),
  ];
}

/// Pairs used to label the section switcher's empty hints.
Set<VitalsMetric> focusFor(String section) => switch (section) {
  'activity' => {VitalsMetric.steps, VitalsMetric.workouts},
  'heart' => {
    VitalsMetric.heartRate,
    VitalsMetric.restingHeartRate,
    VitalsMetric.hrv,
    VitalsMetric.oxygen,
  },
  'body' => {VitalsMetric.weight},
  _ => VitalsMetric.values.toSet(),
};

/// Whether every metric in [focus] is allowed.
bool hasAllMetrics(VitalsSummary? vitals, Set<VitalsMetric> focus) =>
    vitals != null && focus.every(vitals.readMetrics.contains);
