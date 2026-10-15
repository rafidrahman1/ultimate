import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/json_file_cache.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';

const _cacheKey = 'data_cache_expenses_v1';

/// Persists the last-loaded expenses so it survives app restarts.
abstract final class ExpensesCache {
  static Future<ExpensesSummary?> load() async {
    final map = await JsonFileCache.instance.read(_cacheKey);
    if (map == null) return null;
    try {
      return _expensesFromJson(map);
    } catch (e) {
      AppLog.warn('Failed to load expenses cache: $e');
      return null;
    }
  }

  static Future<void> save(ExpensesSummary summary) async {
    if (summary.transactions.isEmpty) return;
    await JsonFileCache.instance.write(_cacheKey, _expensesToJson(summary));
  }

  static Future<void> clear() => JsonFileCache.instance.remove(_cacheKey);
}

/// Bumped when the cached expenses gain data a re-import would add (loans,
/// transaction type, recurrence).
const _expensesCacheSchema = 2;

Map<String, dynamic> _expensesToJson(ExpensesSummary summary) => {
  'schema': _expensesCacheSchema,
  'fileName': summary.fileName,
  'transactions': summary.transactions.map(_transactionToJson).toList(),
  'loans': summary.loans.map(_loanToJson).toList(),
};

ExpensesSummary _expensesFromJson(Map<String, dynamic> json) {
  final items = json['transactions'];
  final transactions = items is List
      ? items
            .whereType<Map>()
            .map((e) => _transactionFromJson(e.cast<String, dynamic>()))
            .toList()
      : <CashewTransaction>[];
  final loanItems = json['loans'];
  final loans = loanItems is List
      ? loanItems
            .whereType<Map>()
            .map((e) => _loanFromJson(e.cast<String, dynamic>()))
            .toList()
      : <CashewLoan>[];
  return ExpensesSummary(
    transactions: transactions,
    loans: loans,
    isLegacyCache: (json['schema'] as num?)?.toInt() != _expensesCacheSchema,
    fileName: json['fileName'] as String?,
  );
}

Map<String, dynamic> _loanToJson(CashewLoan loan) => {
  'dir': loan.direction.name,
  'unpaid': loan.unpaid,
  'date': loan.date.toIso8601String(),
  'currency': loan.currency,
  'person': loan.person,
  'note': loan.note,
};

CashewLoan _loanFromJson(Map<String, dynamic> json) => CashewLoan(
  direction: json['dir'] == 'borrowed'
      ? CashewTxType.borrowed
      : CashewTxType.lent,
  unpaid: (json['unpaid'] as num?)?.toDouble() ?? 0,
  date: DateTime.parse(json['date'] as String),
  currency: json['currency'] as String? ?? 'BDT',
  person: json['person'] as String?,
  note: json['note'] as String?,
);

Map<String, dynamic> _transactionToJson(CashewTransaction tx) => {
  'account': tx.account,
  'amount': tx.amount,
  'currency': tx.currency,
  'date': tx.date.toIso8601String(),
  'isIncome': tx.isIncome,
  'title': tx.title,
  'note': tx.note,
  'category': tx.category,
  'subcategory': tx.subcategory,
  'type': tx.type.name,
  'recurrence': tx.recurrence,
};

CashewTransaction _transactionFromJson(Map<String, dynamic> json) {
  final dateRaw = json['date'] as String?;
  final date = dateRaw == null ? DateTime.now() : DateTime.parse(dateRaw);
  return CashewTransaction(
    account: json['account'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    currency: json['currency'] as String? ?? '',
    date: date,
    isIncome: json['isIncome'] as bool? ?? false,
    title: json['title'] as String?,
    note: json['note'] as String?,
    category: json['category'] as String?,
    subcategory: json['subcategory'] as String?,
    type: CashewTxType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => CashewTxType.normal,
    ),
    recurrence: json['recurrence'] as String?,
  );
}
