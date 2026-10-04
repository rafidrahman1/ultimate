import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/features/home/widgets/feature_tile.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/sparkline.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(
    body: Center(child: SizedBox(width: 180, height: 140, child: child)),
  ),
);

void main() {
  testWidgets('tile shows headline value and caption', (tester) async {
    await tester.pumpWidget(
      _host(
        FeatureTile(
          label: 'Health',
          color: Colors.teal,
          icon: Icons.favorite_rounded,
          stat: const HomeTileStat('7.2 h', 'avg sleep'),
          onPressed: () {},
        ),
      ),
    );
    expect(find.text('7.2 h'), findsOneWidget);
    expect(find.text('avg sleep'), findsOneWidget);
    expect(find.bySemanticsLabel('Health, 7.2 h avg sleep'), findsOneWidget);
  });

  testWidgets('tile draws a sparkline when a series is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FeatureTile(
          label: 'Expenses',
          color: Colors.pink,
          icon: Icons.account_balance_wallet_rounded,
          stat: const HomeTileStat('\$120', 'spent', series: [1, 3, 2, 5]),
          onPressed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Sparkline), findsOneWidget);
  });

  testWidgets('tile reports loading instead of "no data"', (tester) async {
    await tester.pumpWidget(
      _host(
        FeatureTile(
          label: 'Health',
          color: Colors.teal,
          icon: Icons.favorite_rounded,
          loading: true,
          onPressed: () {},
        ),
      ),
    );
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.text('No data yet'), findsNothing);
  });

  testWidgets('AppCard forwards taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(AppCard(onTap: () => taps++, child: const Text('hi'))),
    );
    await tester.tap(find.text('hi'));
    expect(taps, 1);
  });
}
