import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohealth/app/app.dart';
import 'package:motohealth/core/storage/json_file_cache.dart';
import 'package:motohealth/features/garage/maintenance_catalog.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('motohealth_test');
    JsonFileCache.directoryOverride = () async => dir;
  });

  tearDown(() async {
    JsonFileCache.directoryOverride = null;
    await dir.delete(recursive: true);
  });

  testWidgets('first run asks for a bike, then shows the tabs', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Loading reads a file; real I/O has to start outside fake async.
    await tester.runAsync(() => container.read(motoStoreProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MotoHealthApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to MotoHealth'), findsOneWidget);
    expect(find.text('Restore from a backup'), findsOneWidget);

    await tester.runAsync(
      () => container
          .read(motoStoreProvider.notifier)
          .addBike(
            Bike(
              id: 'b',
              name: 'Daily',
              addedOn: DateTime(2026, 1, 1),
              startOdometer: 500,
              tasks: starterTasks(),
            ),
          ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily'), findsWidgets);
    for (final label in ['Home', 'Fuel', 'Service', 'Costs', 'Papers']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Service').last);
    await tester.pumpAndSettle();
    expect(find.text('Engine oil'), findsOneWidget);
    await tester.tap(find.text('Costs').last);
    await tester.pumpAndSettle();
    expect(find.text('Where it goes'), findsNothing);
    await tester.tap(find.text('Papers').last);
    await tester.pumpAndSettle();
    expect(find.text('No papers yet'), findsOneWidget);
  });
}
