import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/features/home/widgets/feature_tile.dart';

/// Mirrors the Home grid cell: same width on a 360dp phone, and the height
/// formula `48 + textScaler.scale(86)` used by `HomeScreen`.
void main() {
  for (final entry in {
    'dark': AppTheme.darkTheme,
    'light': AppTheme.lightTheme,
  }.entries) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('tile fits its grid cell (${entry.key}, ${scale}x text)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: entry.value,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) {
                final height = 48 + MediaQuery.textScalerOf(context).scale(86);
                return Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: (360 - 40 - 10) / 2,
                      height: height,
                      child: FeatureTile(
                        label: 'Game activity',
                        color: Colors.indigo,
                        icon: Icons.sports_esports_rounded,
                        stat: const HomeTileStat(
                          '12.5 h',
                          'played this month',
                          series: [1, 4, 2, 6, 3],
                        ),
                        onPressed: () {},
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }
}
