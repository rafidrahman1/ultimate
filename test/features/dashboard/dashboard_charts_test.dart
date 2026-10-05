import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/dashboard_charts.dart';
import 'package:personal/features/dashboard/dashboard_view_data.dart';

Widget _host(Widget child, {double width = 320, double textScale = 1}) =>
    MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a month of bars fits the width without scrolling sideways', (
    tester,
  ) async {
    final items = [
      for (var i = 1; i <= 31; i++)
        DashboardBarItem(
          label: '$i',
          value: i % 3 == 0 ? 0 : 6.0 + i % 4,
          displayValue: '${6 + i % 4} h',
        ),
    ];
    await tester.pumpWidget(
      _host(
        DashboardColumnChart(items: items, color: Colors.teal, targetLine: 7),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Only the test host scrolls; the chart no longer scrolls sideways.
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('few bars keep their value labels', (tester) async {
    await tester.pumpWidget(
      _host(
        const DashboardColumnChart(
          items: [
            DashboardBarItem(label: 'Mon', value: 3, displayValue: '3'),
            DashboardBarItem(label: 'Tue', value: 1, displayValue: '1'),
          ],
          color: Colors.purple,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('lead row with a ring fits at ${scale}x text', (tester) async {
      await tester.pumpWidget(
        _host(
          textScale: scale,
          const DashboardLeadRow(
            percent: 72,
            ringLabel: 'of budget',
            ringColor: Colors.pink,
            metrics: [
              (label: 'Income used', value: '64%', color: Colors.teal),
              (label: 'Net', value: '৳12,345', color: Colors.green),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('72%'), findsOneWidget);
    });
  }

  testWidgets('lead row without a percentage shows metric tiles only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const DashboardLeadRow(
          percent: null,
          ringLabel: 'x',
          ringColor: Colors.pink,
          metrics: [(label: 'Net', value: '5', color: Colors.green)],
        ),
      ),
    );
    expect(find.byType(RingGauge), findsNothing);
    expect(find.text('Net'), findsOneWidget);
  });
}
