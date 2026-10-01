import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/core/data_cache_service.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';

const _expensesKey = 'data_cache_expenses_v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('data_cache_test');
    DataCacheService.directoryOverride = () async => dir;
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  final summary = ExpensesSummary(
    transactions: [
      CashewTransaction(
        account: 'Cash',
        amount: -250,
        currency: 'BDT',
        date: DateTime(2026, 9, 3),
        isIncome: false,
        category: 'Food',
      ),
    ],
  );

  test('saves to a file and loads it back', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = DataCacheService.instance;

    await cache.saveExpenses(summary);
    final loaded = await cache.loadExpenses();

    expect(loaded?.transactions.single.amount, -250);
    expect(File('${dir.path}/$_expensesKey.json').existsSync(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(_expensesKey), isFalse);
  });

  test('corrupt legacy prefs entry loads as empty and is cleared', () async {
    SharedPreferences.setMockInitialValues({_expensesKey: '{not valid json'});

    expect(await DataCacheService.instance.loadExpenses(), isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(_expensesKey), isFalse);
  });

  test('corrupt cache file loads as empty and is deleted', () async {
    SharedPreferences.setMockInitialValues({});
    final file = File('${dir.path}/$_expensesKey.json')
      ..writeAsStringSync('[1, 2');

    expect(await DataCacheService.instance.loadExpenses(), isNull);
    expect(file.existsSync(), isFalse);
  });
}
