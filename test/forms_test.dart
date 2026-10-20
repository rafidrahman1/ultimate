import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohealth/core/storage/json_file_cache.dart';
import 'package:motohealth/features/costs/expense_form.dart';
import 'package:motohealth/features/dashboard/odometer_form.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/features/papers/paper_form.dart';
import 'package:motohealth/features/service/service_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _bike = Bike(
  id: 'b',
  name: 'Daily',
  addedOn: DateTime(2026, 1, 1),
  startOdometer: 500,
  tasks: const [ServiceTask(id: 'oil', name: 'Engine oil', intervalKm: 3000)],
);

void main() {
  late Directory dir;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('motohealth_forms');
    JsonFileCache.directoryOverride = () async => dir;
    JsonFileCache.instance.resetForTests();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    JsonFileCache.directoryOverride = null;
    await dir.delete(recursive: true);
  });

  MotoData data() => container.read(motoStoreProvider).requireValue;

  /// Opens [show] from a button, with a store that already holds the bike.
  Future<void> open(
    WidgetTester tester,
    Future<void> Function(BuildContext) show,
  ) async {
    await tester.runAsync(() async {
      await container.read(motoStoreProvider.future);
      await container.read(motoStoreProvider.notifier).addBike(_bike);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pump();
    // Let the file write finish before the temp directory is removed.
    await tester.runAsync(() => JsonFileCache.instance.read('moto_data_v1'));
    await tester.pumpAndSettle();
  }

  testWidgets('service: a ticked job is recorded against the visit', (
    tester,
  ) async {
    await open(tester, (c) => showServiceForm(c, bike: _bike));
    await tester.tap(find.text('Engine oil'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Odometer (optional)'),
      '900',
    );
    await save(tester);
    final s = data().services.single;
    expect(s.taskIds, ['oil']);
    expect(s.odometer, 900);
    expect(s.title, isNotEmpty);
  });

  testWidgets('service: a lower odometer than an earlier one is refused', (
    tester,
  ) async {
    await open(tester, (c) => showServiceForm(c, bike: _bike));
    await tester.tap(find.text('Engine oil'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Odometer (optional)'),
      '100',
    );
    await save(tester);
    expect(data().services, isEmpty);
    expect(find.textContaining('Lower than'), findsOneWidget);
  });

  testWidgets('expense: saves an amount', (tester) async {
    await open(tester, (c) => showExpenseForm(c, bike: _bike));
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '450');
    await save(tester);
    expect(data().expenses.single.amount, 450);
  });

  testWidgets('expense: refuses an empty amount', (tester) async {
    await open(tester, (c) => showExpenseForm(c, bike: _bike));
    await save(tester);
    expect(data().expenses, isEmpty);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('paper: defaults to the registration certificate', (
    tester,
  ) async {
    await open(tester, (c) => showPaperForm(c, bike: _bike));
    await save(tester);
    expect(data().papers.single.type, PaperType.registration);
  });

  testWidgets('odometer: logs a reading', (tester) async {
    await open(tester, (c) => showOdometerForm(c, bike: _bike));
    await tester.enterText(find.byType(TextFormField), '800');
    await save(tester);
    expect(data().readings.single.km, 800);
  });
}
