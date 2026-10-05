import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/prefs.dart';

const _excludedCategoriesKey = 'expense_excluded_categories_v1';

/// Cashew top-level categories the user chose to leave out of expense totals.
final excludedExpenseCategoriesProvider =
    NotifierProvider<ExcludedExpenseCategoriesNotifier, Set<String>>(
      ExcludedExpenseCategoriesNotifier.new,
    );

class ExcludedExpenseCategoriesNotifier extends Notifier<Set<String>> {
  static Set<String> _memoryFallback = const {};

  // Keeps the async prefs hydration from overwriting a selection made
  // while it was in-flight.
  bool _userOverrode = false;

  @override
  Set<String> build() {
    unawaited(_hydrateFromPrefs());
    return _memoryFallback;
  }

  Future<void> _hydrateFromPrefs() async {
    final prefs = await safePrefs();
    if (prefs == null || _userOverrode) return;
    final stored = prefs.getStringList(_excludedCategoriesKey);
    if (stored == null || _userOverrode) return;
    final loaded = Set<String>.unmodifiable(stored);
    _memoryFallback = loaded;
    state = loaded;
  }

  Future<void> setExcluded(Set<String> categories) async {
    _userOverrode = true;
    final next = Set<String>.unmodifiable(categories);
    _memoryFallback = next;
    state = next;

    final prefs = await safePrefs();
    await prefs?.setStringList(_excludedCategoriesKey, next.toList()..sort());
  }
}
