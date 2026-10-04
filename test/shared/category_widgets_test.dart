import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/category/category_hero.dart';
import 'package:personal/shared/widgets/category/day_bars.dart';
import 'package:personal/shared/widgets/category/month_grid.dart';

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  theme: AppTheme.darkTheme,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  ),
);

void main() {
  test('buildDayBars buckets by day and ignores other months', () {
    final month = DateTime(2024, 2, 1);
    final bars = buildDayBars([
      (date: DateTime(2024, 2, 3), value: 2),
      (date: DateTime(2024, 2, 3), value: 1.5),
      (date: DateTime(2024, 3, 1), value: 9),
    ], month);
    expect(bars.length, 29);
    expect(bars[2].value, 3.5);
    expect(bars.fold<double>(0, (s, d) => s + d.value), 3.5);
  });

  test('groupByDay orders days and keeps items together', () {
    final items = [
      DateTime(2024, 5, 2, 9),
      DateTime(2024, 5, 1, 20),
      DateTime(2024, 5, 2, 18),
    ];
    final newest = groupByDay(items, (d) => d);
    expect(newest.map((g) => g.key.day), [2, 1]);
    expect(newest.first.value.length, 2);
    expect(groupByDay(items, (d) => d, newestFirst: false).first.key.day, 1);
  });

  testWidgets('DayBars shows the average, then the tapped day', (tester) async {
    final data = [
      for (var i = 1; i <= 10; i++)
        DayBarDatum(DateTime(2024, 5, i), i.isEven ? 2.0 : 0),
    ];
    await tester.pumpWidget(
      _host(
        DayBars(
          data: data,
          color: Colors.teal,
          format: (v) => '${v.toStringAsFixed(1)} h',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Average per active day'), findsOneWidget);
    expect(find.text('2.0 h'), findsOneWidget);

    await tester.tapAt(
      tester.getTopLeft(find.byType(CustomPaint).last) + const Offset(5, 40),
    );
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('DayBars says so when there is nothing to draw', (tester) async {
    await tester.pumpWidget(
      _host(
        DayBars(
          data: [DayBarDatum(DateTime(2024, 5, 1), 0)],
          color: Colors.teal,
          format: (v) => '$v',
          emptyLabel: 'Nothing here',
        ),
      ),
    );
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('MonthHeatGrid selects and clears a day', (tester) async {
    int? selected;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => MonthHeatGrid(
            month: DateTime(2024, 5, 1),
            counts: const {3: 2, 10: 1},
            holidays: const {20},
            color: Colors.purple,
            selectedDay: selected,
            onSelect: (d) => setState(() => selected = d),
          ),
        ),
      ),
    );
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(selected, 3);
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(selected, isNull);
    expect(find.bySemanticsLabel('3 May, 2 events'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('CategoryHero fits at ${scale}x text', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          textScale: scale,
          const CategoryHero(
            accent: Colors.teal,
            icon: Icons.bedtime_rounded,
            label: 'Average sleep',
            value: '7h 12m',
            caption: '24 of 30 nights tracked',
            footnote: '1 – 30 Sep 2025',
            stats: [
              HeroStat('Avg bedtime', '23:40'),
              HeroStat('Avg wake', '07:05'),
              HeroStat('Best night', '9h 2m'),
              HeroStat('Shortest', '4h 50m'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('7h 12m'), findsOneWidget);
    });
  }
}
