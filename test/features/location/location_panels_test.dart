import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/location/location_insights_providers.dart';
import 'package:personal/features/location/location_panels.dart';
import 'package:personal/features/location/place_stats.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/timeline_profile.dart';

const _home = GeoPoint(23.8679, 90.4053);
const _work = GeoPoint(23.8593, 90.3651);
const _cafe = GeoPoint(23.7, 90.3);

TimelinePlaceVisit _visit(
  String id,
  DateTime start,
  DateTime end, {
  String? type,
  required GeoPoint point,
}) => TimelinePlaceVisit(
  startTime: start,
  endTime: end,
  name: 'x',
  semanticType: type,
  placeId: id,
  point: point,
);

LocationSummary _summary() {
  final visits = <TimelinePlaceVisit>[];
  for (var d = 1; d <= 20; d++) {
    visits
      ..add(
        _visit(
          'h',
          DateTime(2026, 9, d),
          DateTime(2026, 9, d, 9, 40),
          type: 'TYPE_HOME',
          point: _home,
        ),
      )
      ..add(
        _visit(
          'w',
          DateTime(2026, 9, d, 10),
          DateTime(2026, 9, d, 17),
          type: 'TYPE_WORK',
          point: _work,
        ),
      )
      ..add(
        _visit(
          'h',
          DateTime(2026, 9, d, 17, 40),
          DateTime(2026, 9, d, 23, 59),
          type: 'TYPE_HOME',
          point: _home,
        ),
      )
      ..add(
        _visit(
          'c$d',
          DateTime(2026, 9, d, 20),
          DateTime(2026, 9, d, 21),
          point: GeoPoint(23.7 + d * 0.01, 90.3),
        ),
      );
  }
  return LocationSummary(
    activities: [
      for (var m = 1; m <= 9; m++)
        TimelineActivity(
          startTime: DateTime(2026, m, 5, 9),
          endTime: DateTime(2026, m, 5, 9, 30),
          type: 'MOTORCYCLING',
          distanceMeters: 8000.0 * m,
        ),
    ],
    placeVisits: visits,
    profile: LocationProfile(
      places: const [
        ProfilePlace(placeId: 'h', point: _home, label: 'HOME'),
        ProfilePlace(placeId: 'w', point: _work, label: 'WORK'),
      ],
      trips: const [
        FrequentTrip(
          direction: CommuteDirection.homeToWork,
          weekday: DateTime.sunday,
          startMinutes: 606,
          durationMinutes: 21,
          modeShares: {'MOTORCYCLING': 0.7},
        ),
      ],
    ),
    trips: [
      TimelineTrip(
        startTime: DateTime(2026, 8, 10),
        endTime: DateTime(2026, 8, 15),
        distanceFromOriginKm: 239,
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width * 3, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  final summary = _summary();
  final insights = computeLocationInsights(
    summary,
    DateTime(2026, 9, 1),
    DateTime(2026, 9, 30, 23, 59),
  );
  final history = buildMonthlyHistory(summary);
  const accent = Colors.teal;

  for (final scale in [1.0, 2.0]) {
    group('at ${scale}x text on a 360dp screen', () {
      testWidgets('time split lays out and names its three parts', (t) async {
        await _pump(
          t,
          TimeSplitPanel(
            insights: insights,
            accent: accent,
            workColor: Colors.indigo,
          ),
          scale: scale,
        );
        expect(t.takeException(), isNull);
        expect(find.text('At home'), findsOneWidget);
        expect(find.text('At work'), findsOneWidget);
        expect(find.text('Elsewhere'), findsOneWidget);
      });

      testWidgets('commute shows measured and expected time', (t) async {
        await _pump(
          t,
          CommutePanel(
            commute: insights.commute,
            profile: summary.profile,
            accent: accent,
          ),
          scale: scale,
        );
        expect(t.takeException(), isNull);
        expect(find.textContaining('To work'), findsOneWidget);
        expect(find.textContaining('Google expects 21 m'), findsOneWidget);
        expect(find.textContaining('Back home'), findsOneWidget);
      });

      testWidgets('places lists the top five and offers the rest', (t) async {
        await _pump(
          t,
          PlacesPanel(
            insights: insights,
            names: const {},
            onRename: (_) async {},
            accent: accent,
          ),
          scale: scale,
        );
        expect(t.takeException(), isNull);
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Work'), findsOneWidget);
        expect(find.textContaining('All '), findsOneWidget);
      });

      testWidgets('monthly trend and trips away lay out', (t) async {
        await _pump(
          t,
          Column(
            children: [
              MonthlyTrendPanel(history: history, accent: accent),
              TripsAwayPanel(trips: summary.trips, accent: accent),
            ],
          ),
          scale: scale,
        );
        expect(t.takeException(), isNull);
        expect(find.text('RIDES BY MONTH'), findsOneWidget);
        expect(find.text('239 km from home'), findsOneWidget);
      });
    });
  }

  testWidgets('a custom place name replaces the generic label', (t) async {
    final cafe = insights.places.firstWhere((p) => p.kind == PlaceKind.other);
    await _pump(
      t,
      PlacesPanel(
        insights: insights,
        names: {cafe.placeId: 'Corner cafe'},
        onRename: (_) async {},
        accent: accent,
      ),
    );
    expect(find.text('Corner cafe'), findsOneWidget);
  });

  testWidgets('tapping a place asks to rename it', (t) async {
    PlaceStat? tapped;
    await _pump(
      t,
      PlacesPanel(
        insights: insights,
        names: const {},
        onRename: (p) async => tapped = p,
        accent: accent,
      ),
    );
    await t.tap(find.text('Home'));
    expect(tapped?.kind, PlaceKind.home);
  });

  testWidgets('the rename dialog returns the typed name, and clears', (
    t,
  ) async {
    String? result = 'unset';
    await _pump(
      t,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showRenamePlaceDialog(
            context,
            current: 'Old',
            fallback: 'Unnamed place',
          ),
          child: const Text('open'),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Gym');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(result, 'Gym');

    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Clear'));
    await t.pumpAndSettle();
    expect(result, '');
  });

  test('placeDisplayName prefers a name, then the kind', () {
    final stat = PlaceStat(
      placeId: 'a',
      placeIds: const ['a', 'b'],
      kind: PlaceKind.other,
      visits: 1,
      totalDwell: Duration.zero,
      firstSeen: DateTime(2026),
      lastSeen: DateTime(2026),
    );
    expect(placeDisplayName(stat, const {}), 'Unnamed place');
    expect(placeDisplayName(stat, const {'b': 'Gym'}), 'Gym');
  });
}
