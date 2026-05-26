import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefix = 'insight_checklist_v1_';

final insightChecklistProvider =
    AsyncNotifierProvider.family<InsightChecklistNotifier, Set<int>, String>(
  InsightChecklistNotifier.new,
);

class InsightChecklistNotifier extends FamilyAsyncNotifier<Set<int>, String> {
  @override
  Future<Set<int>> build(String resultId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$resultId');
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => (e as num).toInt()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> toggle(int index) async {
    final current = state.valueOrNull ?? {};
    final next = Set<int>.from(current);
    if (next.contains(index)) {
      next.remove(index);
    } else {
      next.add(index);
    }
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$arg',
      jsonEncode(next.toList()..sort()),
    );
  }
}
