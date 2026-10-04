import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/results/insight_checklist_service.dart';

void main() {
  test('verifiedAt survives a JSON round trip', () {
    final at = DateTime.utc(2025, 3, 4, 10, 30);
    final state = WeekChecklistState.empty.applyVerification(
      verifiedCompleted: {0},
      verifiedFailed: {1},
      at: at,
    );

    final restored = WeekChecklistState.fromJson(state.toJson());
    expect(restored.verifiedAt, at);
    expect(restored.completed, {0});
    expect(restored.failed, {1});
  });

  test('toggling an item keeps the last verified time', () {
    final at = DateTime.utc(2025, 3, 4);
    final state = WeekChecklistState.empty
        .applyVerification(
          verifiedCompleted: {0},
          verifiedFailed: const {},
          at: at,
        )
        .withStatus(2, ChecklistItemStatus.completed);

    expect(state.verifiedAt, at);
  });

  test('state saved before verifiedAt existed still loads', () {
    final state = WeekChecklistState.fromJson({
      'completed': [0, 2],
      'failed': [1],
    });
    expect(state.verifiedAt, isNull);
    expect(state.completed, {0, 2});
  });
}
