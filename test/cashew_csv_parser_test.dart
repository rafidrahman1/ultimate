import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/expenses/data/cashew_csv_parser.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';

const _header =
    'account,amount,currency,title,note,date,income,type,'
    'category name,subcategory name,amount unpaid,extra';

void main() {
  group('parseCashewExport', () {
    test('parses a comma-separated export', () {
      final csv = [
        _header,
        'Cash,-250.5,BDT,Lunch,,2026-03-02 12:30:00.000,false,0,Food,,,',
        'Bank,50000,BDT,Salary,,2026-03-01 09:00:00.000,true,0,Income,,,',
      ].join('\n');
      final tx = parseCashewCsv(csv);
      expect(tx, hasLength(2));
      expect(tx[0].amount, -250.5);
      expect(tx[0].isIncome, isFalse);
      expect(tx[0].category, 'Food');
      expect(tx[0].date, DateTime(2026, 3, 2, 12, 30));
      expect(tx[1].isIncome, isTrue);
    });

    test('detects tab-separated exports and CRLF line endings', () {
      final csv = [
        _header.replaceAll(',', '\t'),
        'Cash\t-10\tBDT\tTea\t\t2026-03-03 08:00:00.000\tfalse\t0\tFood\t\t\t',
      ].join('\r\n');
      final tx = parseCashewCsv(csv);
      expect(tx, hasLength(1));
      expect(tx.single.title, 'Tea');
    });

    test('defaults the currency to BDT and skips unusable rows', () {
      final csv = [
        _header,
        'Cash,-5,,NoCurrency,,2026-03-04 10:00:00.000,false,0,Food,,,',
        'Cash,notanumber,BDT,Bad,,2026-03-04 10:00:00.000,false,0,Food,,,',
        'Cash,-5,BDT,NoDate,,,false,0,Food,,,',
        ',,,,,,,,,,,',
      ].join('\n');
      final tx = parseCashewCsv(csv);
      expect(tx, hasLength(1));
      expect(tx.single.currency, 'BDT');
    });

    test('empty input yields an empty export', () {
      final export = parseCashewExport('');
      expect(export.transactions, isEmpty);
      expect(export.loans, isEmpty);
    });
  });

  group('CashewTxType.parse', () {
    test('is case-insensitive and falls back to normal', () {
      expect(CashewTxType.parse('Lent'), CashewTxType.lent);
      expect(CashewTxType.parse(' BORROWED '), CashewTxType.borrowed);
      expect(CashewTxType.parse('0'), CashewTxType.normal);
      expect(CashewTxType.parse(null), CashewTxType.normal);
    });
  });
}
