import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cashew_csv_parser.dart';
import 'cashew_transaction.dart';

final expensesSummaryProvider =
    StateNotifierProvider<ExpensesNotifier, ExpensesSummary>((ref) {
  return ExpensesNotifier();
});

class ExpensesNotifier extends StateNotifier<ExpensesSummary> {
  ExpensesNotifier() : super(const ExpensesSummary(transactions: []));

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

    state = ExpensesSummary(transactions: transactions, fileName: name);
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
  }
}
