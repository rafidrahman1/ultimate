import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/results/insight_checklist_service.dart';

void main() {
  test('WeekChecklistState statusFor returns correct status', () {
    const state = WeekChecklistState(
      completed: {0, 2},
      failed: {1},
    );

    expect(state.statusFor(0), ChecklistItemStatus.completed);
    expect(state.statusFor(1), ChecklistItemStatus.failed);
    expect(state.statusFor(2), ChecklistItemStatus.completed);
    expect(state.statusFor(3), ChecklistItemStatus.pending);
  });

  test('toggle cycle pending -> completed -> failed -> pending', () {
    const state = WeekChecklistState.empty;

    final completed = state.withStatus(0, ChecklistItemStatus.completed);
    expect(completed.statusFor(0), ChecklistItemStatus.completed);

    final failed = completed.withStatus(0, ChecklistItemStatus.failed);
    expect(failed.statusFor(0), ChecklistItemStatus.failed);
    expect(failed.completed, isEmpty);

    final pending = failed.withStatus(0, ChecklistItemStatus.pending);
    expect(pending.statusFor(0), ChecklistItemStatus.pending);
    expect(pending.failed, isEmpty);
  });

  test('applyVerification moves indices between completed and failed', () {
    const state = WeekChecklistState(completed: {0});

    final next = state.applyVerification(
      verifiedCompleted: {1},
      verifiedFailed: {0},
    );

    expect(next.completed, {1});
    expect(next.failed, {0});
  });

  test('resolvedCount includes completed and failed', () {
    const state = WeekChecklistState(completed: {0}, failed: {1});
    expect(state.resolvedCount({0, 1, 2}), 2);
  });

  test('fromJson round-trips', () {
    const original = WeekChecklistState(completed: {0, 3}, failed: {2});
    final decoded = WeekChecklistState.fromJson(original.toJson());
    expect(decoded.completed, original.completed);
    expect(decoded.failed, original.failed);
  });
}
