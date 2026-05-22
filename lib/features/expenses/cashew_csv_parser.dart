import 'package:csv/csv.dart';

import 'cashew_transaction.dart';

/// Parses Cashew budget app CSV exports.
List<CashewTransaction> parseCashewCsv(String content) {
  final rows = const CsvToListConverter(
    shouldParseNumbers: false,
  ).convert(content);

  if (rows.isEmpty) return [];

  final header = rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
  final index = _ColumnIndex.fromHeader(header);

  final transactions = <CashewTransaction>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.isEmpty || _rowIsBlank(row)) continue;

    final transaction = _parseRow(row, index);
    if (transaction != null) transactions.add(transaction);
  }
  return transactions;
}

class _ColumnIndex {
  _ColumnIndex({
    required this.account,
    required this.amount,
    required this.currency,
    required this.title,
    required this.note,
    required this.date,
    required this.income,
    required this.category,
    required this.subcategory,
  });

  final int account;
  final int amount;
  final int currency;
  final int title;
  final int note;
  final int date;
  final int income;
  final int category;
  final int subcategory;

  factory _ColumnIndex.fromHeader(List<String> header) {
    int col(String name) => header.indexOf(name);

    return _ColumnIndex(
      account: col('account'),
      amount: col('amount'),
      currency: col('currency'),
      title: col('title'),
      note: col('note'),
      date: col('date'),
      income: col('income'),
      category: col('category name'),
      subcategory: col('subcategory name'),
    );
  }
}

CashewTransaction? _parseRow(List<dynamic> row, _ColumnIndex index) {
  String cell(int i) {
    if (i < 0 || i >= row.length) return '';
    return row[i].toString().trim();
  }

  final amountRaw = cell(index.amount);
  if (amountRaw.isEmpty) return null;

  final amount = double.tryParse(amountRaw);
  if (amount == null) return null;

  final dateRaw = cell(index.date);
  if (dateRaw.isEmpty) return null;

  final date = DateTime.tryParse(dateRaw.replaceFirst('.000', ''));
  if (date == null) return null;

  final incomeRaw = cell(index.income).toLowerCase();
  final isIncome = incomeRaw == 'true' || incomeRaw == '1';

  String? optional(int i) {
    final value = cell(i);
    return value.isEmpty ? null : value;
  }

  return CashewTransaction(
    account: cell(index.account),
    amount: amount,
    currency: cell(index.currency).isEmpty ? 'BDT' : cell(index.currency),
    date: date,
    isIncome: isIncome,
    title: optional(index.title),
    note: optional(index.note),
    category: optional(index.category),
    subcategory: optional(index.subcategory),
  );
}

bool _rowIsBlank(List<dynamic> row) {
  return row.every((cell) => cell.toString().trim().isEmpty);
}
