import 'package:dir_picker/dir_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal/core/app_log.dart';

const _expensesFolderUriKey = 'expenses_cashew_folder_uri_v1';
const _expensesFolderLabelKey = 'expenses_cashew_folder_label_v1';
const _legacyExpensesFolderPathKey = 'expenses_cashew_folder_path_v1';

final expensesSettingsProvider =
    AsyncNotifierProvider<ExpensesSettingsNotifier, ExpensesSettings>(
  ExpensesSettingsNotifier.new,
);

class ExpensesSettings {
  const ExpensesSettings({
    this.cashewFolderUri,
    this.cashewFolderLabel,
    this.needsReselect = false,
  });

  final String? cashewFolderUri;
  final String? cashewFolderLabel;
  final bool needsReselect;

  bool get hasFolder =>
      cashewFolderUri != null && cashewFolderUri!.trim().isNotEmpty;

  PickedLocation? get pickedLocation {
    if (!hasFolder) return null;
    return IOPickedLocation(Uri.parse(cashewFolderUri!));
  }

  String get displayLabel =>
      cashewFolderLabel ??
      cashewFolderUri ??
      'Pick the folder that contains your Cashew CSV exports.';
}

class ExpensesSettingsNotifier extends AsyncNotifier<ExpensesSettings> {
  static ExpensesSettings _memoryFallback = const ExpensesSettings();

  @override
  Future<ExpensesSettings> build() async {
    final prefs = await _safePrefs();
    if (prefs == null) return _memoryFallback;

    final uri = prefs.getString(_expensesFolderUriKey)?.trim();
    final label = prefs.getString(_expensesFolderLabelKey)?.trim();
    if (uri != null && uri.isNotEmpty) {
      final loaded = ExpensesSettings(
        cashewFolderUri: uri,
        cashewFolderLabel: label?.isEmpty ?? true ? null : label,
      );
      _memoryFallback = loaded;
      return loaded;
    }

    final legacyPath = prefs.getString(_legacyExpensesFolderPathKey)?.trim();
    if (legacyPath != null && legacyPath.isNotEmpty) {
      final loaded = ExpensesSettings(
        cashewFolderLabel: legacyPath,
        needsReselect: true,
      );
      _memoryFallback = loaded;
      return loaded;
    }

    return const ExpensesSettings();
  }

  Future<void> saveFolder(PickedLocation location) async {
    final uri = location.uri;
    if (uri == null) {
      throw ArgumentError('Picked folder has no URI on this platform.');
    }

    final next = ExpensesSettings(
      cashewFolderUri: uri.toString(),
      cashewFolderLabel: _labelFromUri(uri),
    );
    await _persist(next);
  }

  Future<void> clearFolder() => _persist(const ExpensesSettings());

  Future<void> _persist(ExpensesSettings next) async {
    _memoryFallback = next;
    final prefs = await _safePrefs();
    if (prefs != null) {
      if (next.cashewFolderUri == null) {
        await prefs.remove(_expensesFolderUriKey);
        await prefs.remove(_expensesFolderLabelKey);
        await prefs.remove(_legacyExpensesFolderPathKey);
      } else {
        await prefs.setString(_expensesFolderUriKey, next.cashewFolderUri!);
        if (next.cashewFolderLabel == null) {
          await prefs.remove(_expensesFolderLabelKey);
        } else {
          await prefs.setString(
            _expensesFolderLabelKey,
            next.cashewFolderLabel!,
          );
        }
        await prefs.remove(_legacyExpensesFolderPathKey);
      }
    } else {
      AppLog.warn(
        'SharedPreferences unavailable. Using in-memory expenses settings.',
      );
    }
    state = AsyncData(next);
  }

  String _labelFromUri(Uri uri) {
    if (uri.scheme == 'file') {
      return uri.toFilePath();
    }

    final encodedPath = uri.pathSegments.isEmpty ? null : uri.pathSegments.last;
    if (encodedPath == null) return uri.toString();

    final decoded = Uri.decodeComponent(encodedPath);
    final colonIndex = decoded.indexOf(':');
    if (colonIndex >= 0 && colonIndex < decoded.length - 1) {
      return decoded.substring(colonIndex + 1);
    }
    return decoded;
  }

  Future<SharedPreferences?> _safePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on PlatformException catch (error) {
      AppLog.warn('SharedPreferences channel error: $error');
      return null;
    } catch (error) {
      AppLog.warn('SharedPreferences init failed: $error');
      return null;
    }
  }
}
