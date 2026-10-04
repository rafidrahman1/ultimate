import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/health/health_patterns.dart';
import 'package:personal/features/health/health_vitals_sections.dart';
import 'package:personal/features/health/sleep_stage_stats.dart';
import 'package:personal/features/health/vitals_models.dart';
import 'package:personal/shared/widgets/category/trend_line.dart';

VitalsSummary _vitals({
  Set<VitalsMetric>? read,
  bool withWorkouts = true,
  bool withWeight = true,
}) => VitalsSummary(
  periodStart: DateTime(2026, 9, 1),
  periodEnd: DateTime(2026, 9, 30),
  days: [
    for (var d = 1; d <= 30; d++)
      DailyVitals(
        date: DateTime(2026, 9, d),
        steps: d % 7 == 0 ? null : 5000 + d * 120,
        restingHr: 58 + d % 5,
        avgHr: 72 + d % 7,
        minHr: 50,
        maxHr: 150,
        hrvMs: 40 + (d % 9).toDouble(),
        spo2Avg: 95.5 + (d % 3) * 0.4,
        distanceMeters: 3500,
        activeKcal: 280,
      ),
  ],
  workouts: withWorkouts
      ? [
          for (var d = 2; d <= 28; d += 5)
            WorkoutRecord(
              type: d % 2 == 0 ? 'RUNNING' : 'STRENGTH_TRAINING',
              start: DateTime(2026, 9, d, 7),
              end: DateTime(2026, 9, d, 7, 45),
              kcal: 300,
              distanceMeters: d % 2 == 0 ? 6000 : null,
            ),
        ]
      : const [],
  weights: withWeight
      ? [
          WeightReading(time: DateTime(2026, 8, 25), kg: 79.2),
          WeightReading(time: DateTime(2026, 9, 6), kg: 78.8),
          WeightReading(time: DateTime(2026, 9, 20), kg: 78.1),
        ]
      : const [],
  readMetrics: read ?? {for (final m in VitalsMetric.values) m},
  sources: {
    VitalsMetric.steps: {'Samsung Health'},
  },
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width * 3, 12000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 4000),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

Widget _slivers(List<Widget> slivers) => CustomScrollView(slivers: slivers);

void main() {
  for (final scale in [1.0, 2.0]) {
    group('at ${scale}x text on a 360dp screen', () {
      testWidgets('activity lays out with workouts', (t) async {
        late List<Widget> slivers;
        await _pump(
          t,
          Builder(
            builder: (context) {
              slivers = activitySlivers(
                context,
                _vitals(),
                DateTime(2026, 9, 1),
              );
              return _slivers(slivers);
            },
          ),
          scale: scale,
        );
        expect(t.takeException(), isNull);
        expect(find.text('AVERAGE STEPS'), findsOneWidget);
        expect(find.text('STEPS BY DAY'), findsOneWidget);
        expect(find.text('WORKOUTS'), findsOneWidget);
      });

      testWidgets('heart shows resting rate, trend and variability', (t) async {
        await _pump(
          t,
          Builder(
            builder: (context) => _slivers(heartSlivers(context, _vitals())),
          ),
          scale: scale,
        );
        expect(t.takeException(), isNull);
        expect(find.text('RESTING HEART RATE'), findsWidgets);
        expect(find.byType(TrendLine), findsWidgets);
      });

      testWidgets('body shows weight and its readings', (t) async {
        await _pump(
          t,
          Builder(
            builder: (context) => _slivers(bodySlivers(context, _vitals())),
          ),
          scale: scale,
        );
        expect(t.takeException(), isNull);
        expect(find.text('LATEST WEIGHT'), findsOneWidget);
        expect(find.text('78.1 kg'), findsWidgets);
      });

      testWidgets('stages, patterns, connect and status panels lay out', (
        t,
      ) async {
        const stats = SleepStageStats(
          nights: 12,
          avgDeep: Duration(minutes: 70),
          avgLight: Duration(minutes: 230),
          avgRem: Duration(minutes: 100),
          avgAwake: Duration(minutes: 20),
          avgAwakeEpisodes: 2.3,
          avgEfficiency: 0.95,
        );
        const patterns = [
          HealthPattern(
            id: 'steps_after_sleep',
            title: 'Steps',
            labelA: 'after a night under 6 h',
            labelB: 'after 7 h or more',
            valueA: 4000,
            valueB: 8000,
            daysA: 5,
            daysB: 9,
            unit: 'steps',
            strength: 1,
          ),
        ];
        await _pump(
          t,
          SingleChildScrollView(
            child: Column(
              children: [
                const SleepStagesPanel(stats: stats),
                const HealthPatternsPanel(patterns: patterns),
                ConnectVitalsCard(
                  vitals: _vitals(read: {VitalsMetric.steps}),
                  onConnect: () {},
                  connecting: false,
                  focus: focusFor('heart'),
                ),
                VitalsStatusPanel(vitals: _vitals(read: {VitalsMetric.steps})),
              ],
            ),
          ),
          scale: scale,
        );
        expect(t.takeException(), isNull);
        expect(find.text('SLEEP STAGES'), findsOneWidget);
        expect(find.textContaining('Asleep 95%'), findsOneWidget);
        expect(find.text('Steps'), findsWidgets);
        expect(
          find.textContaining('Not allowed in Health Connect'),
          findsOneWidget,
        );
      });
    });
  }

  testWidgets('connect card invites first-time connection and reports taps', (
    t,
  ) async {
    var taps = 0;
    await _pump(
      t,
      ConnectVitalsCard(
        vitals: null,
        onConnect: () => taps++,
        connecting: false,
      ),
    );
    expect(find.text('Add activity and heart data'), findsOneWidget);
    await t.tap(find.text('Connect'));
    expect(taps, 1);
  });

  testWidgets('connect card disables itself while waiting', (t) async {
    await _pump(
      t,
      ConnectVitalsCard(vitals: null, onConnect: () {}, connecting: true),
    );
    expect(find.text('Waiting for Health Connect…'), findsOneWidget);
    final button = t.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('status panel separates not-allowed from no-data', (t) async {
    await _pump(
      t,
      SingleChildScrollView(
        child: VitalsStatusPanel(
          vitals: VitalsSummary(
            periodStart: DateTime(2026, 9, 1),
            periodEnd: DateTime(2026, 9, 30),
            days: [DailyVitals(date: DateTime(2026, 9, 1), steps: 4000)],
            readMetrics: {VitalsMetric.steps, VitalsMetric.heartRate},
            sources: {
              VitalsMetric.steps: {'Samsung Health'},
            },
          ),
        ),
      ),
    );
    expect(find.text('1 days · Samsung Health'), findsOneWidget);
    expect(find.text('Allowed, no data this period'), findsOneWidget);
    expect(find.text('Not allowed'), findsWidgets);
  });

  testWidgets('empty sections explain what is missing', (t) async {
    await _pump(
      t,
      Builder(
        builder: (context) => _slivers(
          bodySlivers(
            context,
            _vitals(read: {VitalsMetric.steps}, withWeight: false),
          ),
        ),
      ),
    );
    expect(find.text('Weight isn’t shared with Personal yet.'), findsOneWidget);
  });

  group('TrendLine', () {
    final data = [
      for (var d = 1; d <= 10; d++)
        TrendPoint(DateTime(2026, 9, d), d == 5 ? null : 60.0 + d),
    ];

    testWidgets('shows the average, then a tapped reading', (t) async {
      await _pump(
        t,
        Padding(
          padding: const EdgeInsets.all(16),
          child: TrendLine(
            data: data,
            color: Colors.teal,
            format: (v) => '${v.round()} bpm',
          ),
        ),
      );
      expect(find.text('Average'), findsOneWidget);
      expect(find.text('66 bpm'), findsOneWidget);

      await t.tapAt(
        t.getTopLeft(find.byType(CustomPaint).last) + const Offset(1, 40),
      );
      await t.pump();
      expect(find.text('Average'), findsNothing);
      expect(find.textContaining('Tue 1 Sep'), findsOneWidget);
      expect(find.text('61 bpm'), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
    });

    testWidgets('says so when there are no readings', (t) async {
      await _pump(
        t,
        TrendLine(
          data: [TrendPoint(DateTime(2026, 9, 1), null)],
          color: Colors.teal,
          format: (v) => '$v',
          emptyLabel: 'No readings',
        ),
      );
      expect(find.text('No readings'), findsOneWidget);
    });

    testWidgets('handles a single reading and a flat series', (t) async {
      await _pump(
        t,
        Column(
          children: [
            TrendLine(
              data: [TrendPoint(DateTime(2026, 9, 1), 70)],
              color: Colors.teal,
              format: (v) => '${v.round()}',
            ),
            TrendLine(
              data: [
                for (var d = 1; d <= 5; d++)
                  TrendPoint(DateTime(2026, 9, d), 60),
              ],
              color: Colors.teal,
              format: (v) => '${v.round()}',
            ),
          ],
        ),
      );
      expect(t.takeException(), isNull);
    });
  });
}
