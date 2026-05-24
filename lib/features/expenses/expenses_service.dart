import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uri_content/uri_content.dart';

import 'cashew_csv_parser.dart';
import 'cashew_file_finder.dart';
import 'cashew_transaction.dart';
import 'expenses_settings_service.dart';

final expensesSummaryProvider =
    StateNotifierProvider<ExpensesNotifier, ExpensesSummary>((ref) {
  return ExpensesNotifier(ref);
});

class ExpensesNotifier extends StateNotifier<ExpensesSummary> {
  ExpensesNotifier(this._ref) : super(const ExpensesSummary(transactions: []));

  final Ref _ref;
  final _uriContent = UriContent();

  Future<void> loadFromConfiguredFolder() async {
    final settings = await _ref.read(expensesSettingsProvider.future);
    if (settings.needsReselect) {
      throw FormatException(
        'Folder access expired. Open Expenses settings and choose the folder again.',
      );
    }

    final location = settings.pickedLocation;
    if (location == null) {
      throw FormatException(
        'No Cashew folder selected. Open Expenses settings from the menu.',
      );
    }

    final match = await findLatestCashewCsv(location);
    if (match == null) {
      throw FormatException(
        'No cashew-*.csv export found in "${settings.displayLabel}".',
      );
    }

    await _importFromUri(match);
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

    state = ExpensesSummary(transactions: transactions, fileName: name);
  }

  Future<void> _importFromUri(CashewCsvMatch match) async {
    final bytes = await _uriContent.from(match.uri);
    final content = utf8.decode(bytes);
    if (content.trim().isEmpty) {
      throw FormatException('File "${match.fileName}" is empty');
    }

    final transactions = parseCashewCsv(content);
    if (transactions.isEmpty) {
      throw FormatException('No transactions found in "${match.fileName}"');
    }

    state = ExpensesSummary(
      transactions: transactions,
      fileName: match.fileName,
    );
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
