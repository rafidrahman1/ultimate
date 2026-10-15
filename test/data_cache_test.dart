import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal/core/storage/json_file_cache.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/expenses/data/expenses_cache.dart';

void main() {
  late Directory dir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dir = await Directory.systemTemp.createTemp('data_cache_test');
    JsonFileCache.directoryOverride = () async => dir;
  });

  tearDown(() async {
    JsonFileCache.directoryOverride = null;
    await dir.delete(recursive: true);
  });

  test('JsonFileCache round-trips a map and removes it', () async {
    final cache = JsonFileCache.instance;
    expect(await cache.read('k'), isNull);
    await cache.write('k', {'a': 1, 'b': 'two'});
    expect(await cache.read('k'), {'a': 1, 'b': 'two'});
    await cache.remove('k');
    expect(await cache.read('k'), isNull);
  });

  test('a corrupt entry reads as null and is cleared', () async {
    File('${dir.path}/bad.json').writeAsStringSync('{not json');
    expect(await JsonFileCache.instance.read('bad'), isNull);
    expect(File('${dir.path}/bad.json').existsSync(), isFalse);
  });

  test('ExpensesCache round-trips transactions and loans', () async {
    final summary = ExpensesSummary(
      fileName: 'export.csv',
      transactions: [
        CashewTransaction(
          account: 'Cash',
          amount: -120.5,
          currency: 'BDT',
          date: DateTime(2026, 3, 2, 12),
          isIncome: false,
          title: 'Lunch',
          category: 'Food',
        ),
      ],
      loans: [
        CashewLoan(
          direction: CashewTxType.lent,
          unpaid: 500,
          date: DateTime(2026, 2, 1),
          currency: 'BDT',
          person: 'Sam',
        ),
      ],
    );
    await ExpensesCache.save(summary);
    final loaded = await ExpensesCache.load();
    expect(loaded, isNotNull);
    expect(loaded!.fileName, 'export.csv');
    expect(loaded.transactions.single.title, 'Lunch');
    expect(loaded.transactions.single.amount, -120.5);
    expect(loaded.loans.single.owedToYou, isTrue);
    expect(loaded.loans.single.person, 'Sam');
  });

  test('empty summaries are not cached', () async {
    await ExpensesCache.save(const ExpensesSummary(transactions: []));
    expect(await ExpensesCache.load(), isNull);
  });
}
