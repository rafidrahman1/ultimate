import 'package:csv/csv.dart';

import 'package:personal/features/expenses/cashew_transaction.dart';

/// A parsed export: the transactions plus the loan records, which have no
/// `amount` and so aren't transactions.
class CashewExport {
  const CashewExport({required this.transactions, required this.loans});

  final List<CashewTransaction> transactions;
  final List<CashewLoan> loans;
}

/// Parses Cashew budget app CSV exports (comma- or tab-separated).
List<CashewTransaction> parseCashewCsv(String content) =>
    parseCashewExport(content).transactions;

/// Like [parseCashewCsv], and also reads the lent/borrowed records.
CashewExport parseCashewExport(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final firstLine = normalized
      .split('\n')
      .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
  final delimiter = _detectDelimiter(firstLine);
  final rows = CsvToListConverter(
    fieldDelimiter: delimiter,
    shouldParseNumbers: false,
    eol: '\n',
  ).convert(normalized);

  if (rows.isEmpty) return const CashewExport(transactions: [], loans: []);

  final header = rows.first
      .map((c) => c.toString().trim().toLowerCase())
      .toList();
  final index = _ColumnIndex.fromHeader(header);

  final transactions = <CashewTransaction>[];
  final loans = <CashewLoan>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.isEmpty || _rowIsBlank(row)) continue;

    final transaction = _parseRow(row, index);
    if (transaction != null) transactions.add(transaction);
    final loan = _parseLoan(row, index);
    if (loan != null) loans.add(loan);
  }
  return CashewExport(transactions: transactions, loans: loans);
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
    required this.type,
    required this.amountUnpaid,
    required this.extra,
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
  final int type;
  final int amountUnpaid;
  final int extra;

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
      type: col('type'),
      amountUnpaid: col('amount unpaid'),
      extra: col('extra'),
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
    type: CashewTxType.parse(cell(index.type)),
    recurrence: optional(index.extra),
  );
}

/// Lent/borrowed rows carry the unsettled sum in `amount unpaid`; their
/// `amount` is usually empty.
CashewLoan? _parseLoan(List<dynamic> row, _ColumnIndex index) {
  String cell(int i) {
    if (i < 0 || i >= row.length) return '';
    return row[i].toString().trim();
  }

  final type = CashewTxType.parse(cell(index.type));
  if (type != CashewTxType.lent && type != CashewTxType.borrowed) return null;

  final unpaid = double.tryParse(cell(index.amountUnpaid));
  if (unpaid == null || unpaid == 0) return null;

  final date = DateTime.tryParse(cell(index.date).replaceFirst('.000', ''));
  if (date == null) return null;

  String? optional(int i) {
    final value = cell(i);
    return value.isEmpty ? null : value;
  }

  return CashewLoan(
    direction: type,
    unpaid: unpaid.abs(),
    date: date,
    currency: cell(index.currency).isEmpty ? 'BDT' : cell(index.currency),
    person: optional(index.title),
    note: optional(index.note),
  );
}

bool _rowIsBlank(List<dynamic> row) {
  return row.every((cell) => cell.toString().trim().isEmpty);
}

String _detectDelimiter(String headerLine) {
  final commaCount = ','.allMatches(headerLine).length;
  final tabCount = '\t'.allMatches(headerLine).length;
  return tabCount > commaCount ? '\t' : ',';
}
