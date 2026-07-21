import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/data_cache_service.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/expenses/cashew_csv_parser.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/google_drive_client.dart';

final expensesSummaryProvider =
    StateNotifierProvider<ExpensesNotifier, ExpensesSummary>((ref) {
      final notifier = ExpensesNotifier(ref);
      unawaited(notifier.restoreFromCache());
      return notifier;
    });

class ExpensesNotifier extends StateNotifier<ExpensesSummary> {
  ExpensesNotifier(this._ref) : super(const ExpensesSummary(transactions: [])) {
    _driveClient = GoogleDriveClient(
      accountService: _ref.read(googleAccountServiceProvider),
    );
  }

  final Ref _ref;
  late final GoogleDriveClient _driveClient;
  bool _cacheRestored = false;

  Future<void> restoreFromCache() async {
    if (_cacheRestored) return;
    _cacheRestored = true;
    final cached = await DataCacheService.instance.loadExpenses();
    if (cached != null && cached.transactions.isNotEmpty) {
      state = cached;
    }
  }

  void _commit(ExpensesSummary summary) {
    state = summary;
    if (summary.transactions.isNotEmpty) {
      unawaited(DataCacheService.instance.saveExpenses(summary));
    }
  }

  Future<void> loadFromGoogleDrive({bool interactiveSignIn = false}) async {
    try {
      final result = await _driveClient.fetchCashewOutboxCsv(
        interactiveSignIn: interactiveSignIn,
      );

      final transactions = parseCashewCsv(result.content);
      if (transactions.isEmpty) {
        throw FormatException(
          'No transactions found in "${result.fileName}" from Google Drive.',
        );
      }

      _commit(
        ExpensesSummary(
          transactions: transactions,
          fileName: '${result.fileName} (${result.accountEmail})',
        ),
      );
    } on FormatException {
      if (!interactiveSignIn && state.transactions.isNotEmpty) {
        return;
      }
      rethrow;
    }
  }

  Future<void> importFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final name = file.name;

    final content = await _readFileContent(file);
    if (content == null || content.trim().isEmpty) {
      throw FormatException('Could not read "$name"');
    }

    final transactions = parseCashewCsv(content);
    if (transactions.isEmpty) {
      throw FormatException('No transactions found in "$name"');
    }

    _commit(ExpensesSummary(transactions: transactions, fileName: name));
  }

  Future<String?> _readFileContent(PlatformFile file) async {
    if (file.bytes != null) {
      return String.fromCharCodes(file.bytes!);
    }
    if (file.path != null) {
      return File(file.path!).readAsString();
    }
    return null;
  }

  void clear() {
    state = const ExpensesSummary(transactions: []);
    unawaited(DataCacheService.instance.clearExpenses());
  }
}
