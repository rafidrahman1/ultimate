import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/prefs.dart';

const _dashboardCardOrderKey = 'dashboard_card_order_v1';

/// Reorderable analysis cards on the dashboard, in their default order.
enum DashboardCardId {
  stableMonth,
  health,
  financial,
  mobility,
  gaming,
  calendar,
}

final dashboardCardOrderProvider =
    NotifierProvider<DashboardCardOrderNotifier, List<DashboardCardId>>(
      DashboardCardOrderNotifier.new,
    );

class DashboardCardOrderNotifier extends Notifier<List<DashboardCardId>> {
  static List<DashboardCardId> _memoryFallback = DashboardCardId.values;

  // Prevents a slow prefs read from undoing a drag made before it finished.
  bool _userOverrode = false;

  @override
  List<DashboardCardId> build() {
    unawaited(_hydrateFromPrefs());
    return _memoryFallback;
  }

  /// Moves the card at [oldIndex] to [newIndex] (post-removal index) among
  /// the [visible] cards.
  ///
  /// Hidden cards (no data this month) keep their slots in the full order.
  Future<void> reorderVisible({
    required List<DashboardCardId> visible,
    required int oldIndex,
    required int newIndex,
  }) async {
    final reordered = List.of(visible);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    final visibleSet = visible.toSet();
    var slot = 0;
    final next = [
      for (final id in state)
        if (visibleSet.contains(id)) reordered[slot++] else id,
    ];
    await _persist(next);
  }

  bool get isDefaultOrder => _sameOrder(state, DashboardCardId.values);

  Future<void> reset() => _persist(DashboardCardId.values);

  static bool _sameOrder(List<DashboardCardId> a, List<DashboardCardId> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _hydrateFromPrefs() async {
    final prefs = await safePrefs();
    if (prefs == null || _userOverrode) return;

    final raw = prefs.getStringList(_dashboardCardOrderKey);
    if (raw == null || raw.isEmpty) return;

    final loaded = normalizeDashboardCardOrder(raw);
    if (_userOverrode) return;
    _memoryFallback = loaded;
    state = loaded;
  }

  Future<void> _persist(List<DashboardCardId> next) async {
    _userOverrode = true;
    _memoryFallback = next;
    state = next;

    final prefs = await safePrefs();
    await prefs?.setStringList(
      _dashboardCardOrderKey,
      next.map((id) => id.name).toList(),
    );
  }
}

/// Parses a stored order, dropping unknown ids and appending any new cards.
List<DashboardCardId> normalizeDashboardCardOrder(List<String> raw) {
  final byName = {for (final id in DashboardCardId.values) id.name: id};
  final order = <DashboardCardId>[];
  for (final name in raw) {
    final id = byName[name];
    if (id != null && !order.contains(id)) order.add(id);
  }
  for (final id in DashboardCardId.values) {
    if (!order.contains(id)) order.add(id);
  }
  return order;
}

const _dashboardExpandedKey = 'dashboard_expanded_cards_v1';

/// Analysis cards the user has expanded; everything else stays collapsed to
/// its summary.
final dashboardExpandedCardsProvider =
    NotifierProvider<DashboardExpandedNotifier, Set<DashboardCardId>>(
      DashboardExpandedNotifier.new,
    );

class DashboardExpandedNotifier extends Notifier<Set<DashboardCardId>> {
  static Set<DashboardCardId> _memoryFallback = const {};

  bool _userOverrode = false;

  @override
  Set<DashboardCardId> build() {
    unawaited(_hydrateFromPrefs());
    return _memoryFallback;
  }

  Future<void> toggle(DashboardCardId id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    return _persist(next);
  }

  Future<void> expand(DashboardCardId id) =>
      state.contains(id) ? Future.value() : toggle(id);

  Future<void> _hydrateFromPrefs() async {
    final prefs = await safePrefs();
    if (prefs == null || _userOverrode) return;

    final raw = prefs.getStringList(_dashboardExpandedKey);
    if (raw == null) return;

    final byName = {for (final id in DashboardCardId.values) id.name: id};
    final loaded = {
      for (final name in raw)
        if (byName[name] != null) byName[name]!,
    };
    if (_userOverrode) return;
    _memoryFallback = loaded;
    state = loaded;
  }

  Future<void> _persist(Set<DashboardCardId> next) async {
    _userOverrode = true;
    _memoryFallback = next;
    state = next;

    final prefs = await safePrefs();
    await prefs?.setStringList(
      _dashboardExpandedKey,
      next.map((id) => id.name).toList(),
    );
  }
}
