import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal/app/router.dart';

void main() {
  test('unknown routes do not silently open the main shell', () {
    final screen = AppRoutes.screenFor('/definitely-not-a-route');
    expect(screen.runtimeType.toString(), '_UnknownRouteScreen');
  });

  test('settings sub-pages have their own routes', () {
    for (final route in [
      AppRoutes.aiSettings,
      AppRoutes.notificationSettings,
    ]) {
      expect(
        AppRoutes.screenFor(route).runtimeType.toString(),
        isNot('_UnknownRouteScreen'),
      );
    }
  });

  testWidgets('unknown route screen asserts in debug', (tester) async {
    final screen = AppRoutes.screenFor('/typo');
    await tester.pumpWidget(MaterialApp(home: screen));
    expect(tester.takeException(), isA<AssertionError>());
  });
}
