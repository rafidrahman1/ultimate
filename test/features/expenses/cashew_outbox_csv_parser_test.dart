import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/expenses/cashew_csv_parser.dart';

void main() {
  test('parses tab-separated Cashew outbox.csv rows', () {
    const csv = '''
account\tamount\tamount unpaid\tcurrency\ttitle\tnote\tdate\tincome\ttype\tcategory name\tsubcategory name\tcolor\ticon\temoji\tbudget\tobjective\textra\ttransaction id\tlast modified
Bank\t-2683\t\tBDT\tCursor Pro\tFor Office\t2026-06-19 17:37:05\tFALSE\tdefault\tTech & Learn\tMiscellaneous\t0XFFFF1AC5\tcode\t\t\t\trepeat every 1 month\tb50101bc-afd5-4dac-a824-39a11fc401fd\t2026-06-16 17:13:05
Bank\t-300\t\tBDT\tChicken Fry\tWatch Rick and Morty\t2026-06-15 18:27:08\tFALSE\tdefault\tFood\tSnacks\t0XFFFF5500\tcutlery\t\t\t\trepeat every 1 month\t22009223-90e9-4f60-b7c6-c32284eaffcf\t2026-06-16 17:12:52
''';

    final transactions = parseCashewCsv(csv);

    expect(transactions, hasLength(2));
    expect(transactions.first.title, 'Cursor Pro');
    expect(transactions.first.amount, -2683);
    expect(transactions.first.category, 'Tech & Learn');
    expect(transactions.last.subcategory, 'Snacks');
    expect(transactions.every((tx) => !tx.isIncome), isTrue);
  });
}
